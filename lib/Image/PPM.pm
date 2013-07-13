package Image::PPM;

sub new {
  my $base = shift;
  my $class = ref($base) || $base;
  bless { Z => $base->{Z}, MAX => $base->{MAX} } => $class;
}

sub new_ppm {
  my $base = shift;
  my $class = ref($base) || $base;
  bless { Z => 3, MAX => 225, DEF => "\0\0\0" } => $class;
}

sub new_pbm {
  my $base = shift;
  my $class = ref($base) || $base;
  bless { Z => 1, DEF => 0 } => $class;
}

sub print_ppm {
  my ($self, $fh) = @_;
  $self->set_dimensions();
  print $fh "P6\n", $self->cols, " ", $self->rows, "\n";
  print $fh $self->max, "\n";
  print $fh @{$self->{ROWS}};
}

sub print_pbm {
  my ($self, $fh) = @_;
  $self->set_dimensions();
  print $fh "P1\n", $self->cols, " ", $self->rows, "\n";
  print $fh join "\n", @{$self->{ROWS}}, "";
}

sub all_data {
  my ($self) = @_;
  return join "", @{$self->{ROWS}};
}

sub new_ppm_from_fh {
  my ($class, $fh) = @_;
  my ($magic, $c, $r, $max, $data) = do {
    local $/;
    my $data = <$fh>;
    split /\s+/, $data, 5;
  };
  die "Bad magic number '$magic'" unless $magic eq "P6";
  my $self = $class->new_ppm();
  @{$self}{qw(R C MAX)} = ($r, $c, $max);
  { my $len = length($data);
    die "Bad data length $len" unless $len == $r * $c * 3;
  }
  { my @rows;
    my $row_len = $c * 3;
    for my $row_i (0 .. $r-1) {
      my $off = $row_i * $row_len;
      push @rows, substr($data, $off, $row_len);
    }
    $self->{ROWS} = \@rows;
  }
  return $self;
}

sub new_pbm_from_fh {
  my ($class, $fh) = @_;
  my ($magic, $c, $r, $data) = do {
    local $/;
    my $data = <$fh>;
    split /\s+/, $data, 4;
  };
  die "Bad magic number '$magic'" unless $magic eq "P1";
  my $self = $class->new_pbm();
  @{$self}{qw(R C MAX)} = ($r, $c, $max);
  $data =~ tr/01//cd;
  { my $len = length($data);
    die "Bad data length $len" unless $len == $r * $c;
  }
  { my @rows;
    my $row_len = $c;
    for my $row_i (0 .. $r-1) {
      my $off = $row_i * $row_len;
      push @rows, substr($data, $off, $row_len);
    }
    $self->{ROWS} = \@rows;
  }
  return $self;
}

sub copy {
  my $self = shift;
  my $copy = $self->new();
  %$copy = %$self;
  $copy->{ROWS} = $self->dup_data();
  return $copy;
}

sub dup_data {
  my $self = shift;
  return [ @{$self->{ROWS}} ];
}

sub rows { $_[0]{R} }
sub cols { $_[0]{C} }
sub max { $_[0]{MAX} }
sub dimen { ($_[0]->rows, $_[0]->cols) }

sub get {
  my ($self, $r, $c) = @_;
  return substr($self->{ROWS}[$r], $self->{Z}*$c, $self->{Z});
}

sub avg_box {
  my ($self, $Y, $X, $h, $w) = @_;
  my $sum = 0;

  my $y = $Y;
  while ($y < $Y + $h) {
    my $next_y = int($y+1);
    $next_y = $Y + $h if $next_y > $Y + $h;

    my $x = $X;
    while ($x < $X + $w) {
      my $next_x = int($x+1);
      $next_x = $X + $w if $next_x > $X + $w;
      my $weight = ($next_y - $y) * ($next_x - $x);
      $sum += $self->brightness($y, $x) * $weight;
      $x = $next_x;
    }
    $y = $next_y;
  }
  return $sum / ($w*$h);
}

sub set {
  my ($self, $r, $c, $s) = @_;
  my $z = $self->{Z};
  die "Data length is not a multiple of $z"
    unless length($s) % $z == 0;
  my $deficit = $z * ($c+1) - length($self->{ROWS}[$r]);
  if ($deficit > 0) {
    $self->{ROWS}[$r] .= $self->{DEF} x $deficit;
  }
  substr($self->{ROWS}[$r], $z*$c, $z, $s);
}

sub rgb {
  my ($self, $r, $c) = @_;
  my $M = $self->{MAX};
  my ($R, $G, $B) = map $_/$M, map ord, split //, $self->get($r, $c);
  return wantarray ? ($R, $G, $B) : die ;
}

# WRONG FORMULA HERE
sub brightness {
  my ($self, $r, $c) = @_;
  my ($r, $g, $b) = $self->rgb($r, $c);
  return ($r+$g+$b)/3;  #  what are the right scale factors?
}

sub _max {
  my $max = shift;
  $max = $_ > $max ? $_ : $max for @_;
  return $max;
}

sub row_length {
  my $self = shift;
  my $max = _max(map length, @{$self->{ROWS}});
  for (@{$self->{ROWS}}) {
    $_ .= $self->{DEF} x ($max - length());
  }

#  my $len = length($self->{ROWS}[0]);
#  for my $r (@{$self->{ROWS}}) {
#    die "Length mismatch" unless length($r) == $len;
#    die "Length is not a multiple of $self->{Z}";
#      unless length($r) % $self->{Z} == 0;
#  }
#  return $len / $self->{Z};
   return $max / $self->{Z};
}

sub set_dimensions {
  my $self = shift;
  $self->{C} = $self->row_length;
  $self->{R} = @{$self->{ROWS}};
}

1;
