#!/usr/bin/perl

package BobboBot::rpn;

use BobboBot::users;

use warnings;
use strict;

sub Pi
{
  return atan2(0, -1);
}

sub factorial
{
  my $n = shift();
  my $r = $n;
  my $i = 1;
  $r *= $i while (++$i < $n);
  return $r;
}

sub gcd
{
  my $a = shift();
  my $b = shift();
  while ($a != 0 && $b != 0)
  {
    if ($a > $b)
    {
      $a %= $b;
    }
    else
    {
      $b %= $a;
    }
  }
  return $a || $b;
}

my $last;

my $operators = {
  '+' => { ops => 2, fn => sub { return $_[0] + $_[1] } },
  '-' => { ops => 2, fn => sub { return $_[0] - $_[1] } },
  '*' => { ops => 2, fn => sub { return $_[0] * $_[1] } },
  '/' => { ops => 2, fn => sub { return $_[0] / $_[1] } },
  '^' => { ops => 2, fn => sub { return $_[0] ** $_[1] } },
  '%' => { ops => 2, fn => sub { return $_[0] % $_[1] } },

  'sqrt' => { ops => 1, fn => sub { return sqrt(abs($_[0])) } },
  'root' => { ops => 2, fn => sub { return abs($_[0]) ** (1 / $_[1]) } },
  'log' => { ops => 1, fn => sub { return log($_[0]) } },
  'log10' => { ops => 1, fn => sub { return log($_[0]) / log(10) } }, # fix this
  'logN' => { ops => 2, fn => sub { return log($_[0]) / log($_[1]) } },
  '!' => { ops => 1, fn => sub { return factorial($_[0]) } },

  # trig
  'sin' => { ops => 1, fn => sub { return sin($_[0]) } },
  'asin' => { ops => 1, fn => sub { return atan2($_[0], sqrt(1 - $_[0] * $_[0])) } },
  'cos' => { ops => 1, fn => sub { return cos($_[0]) } },
  'acos' => { ops => 1, fn => sub { return atan2(sqrt(1 - $_[0] * $_[0]), $_[0]) } },
  'tan' => { ops => 1, fn => sub { return sin($_[0]) / cos($_[0]) } }, # sin(x)/cos(x) == tan(x)
  'atan2' => { ops => 2, fn => sub { return atan2($_[0], $_[1]) } },

  # bitwise
  '<<'  => { ops => 2, fn => sub { return $_[0] << $_[1]} },
  '>>'  => { ops => 2, fn => sub { return $_[0] >> $_[1]} },
  'AND' => { ops => 2, fn => sub { return $_[0] & $_[1] } },
  'OR'  => { ops => 2, fn => sub { return $_[0] | $_[1] } },
  'XOR' => { ops => 2, fn => sub { return $_[0] ^ $_[1] } },
  'NOT' => { ops => 1, fn => sub { return ~$_[0] } },

  # special functions
  'min' => { ops => 2, fn => sub { return $_($_[0] < $_[1] ? 0 : 1) } },
  'max' => { ops => 2, fn => sub { return $_($_[0] > $_[1] ? 0 : 1) } },
  'deg'  => { ops => 1, fn => sub { return $_[0] * 180 / Pi() } },
  'rad'  => { ops => 1, fn => sub { return $_[0] * Pi() / 180 } },
  'last' => { ops => 0, fn => sub { return defined $last ? $last : 0 } },
  'time' => { ops => 0, fn => sub { return time() } },
  'gcd'  => { ops => 2, fn => sub { return gcd($_[0], $_[1]) } },

  #constants
  'pi' => { ops => 0, fn => sub { return Pi() } },
  'e'  => { ops => 0, fn => sub { return exp(1) } },
  'c'  => { ops => 0, fn => sub { return 2.997924580e8 } },
  'g'  => { ops => 0, fn => sub { return 9.81 } },
  'G'  => { ops => 0, fn => sub { return 6.67384e-11 } }
};

sub ops
{
  my @ops = sort(keys %{$operators});
  my $ret = $ops[0];

  for (my $i = 1; $i < @ops; $i++)
  {
    $ret .= ', ' . $ops[$i];
  }

  return $ret;
}

sub run
{
  my @stack = @{$_[0]->{arg}};

  if (@stack == 1 && $stack[0] eq 'list')
  {
    return 'Available operators: ' . ops();
  }

  foreach my $arg (@stack)
  {
    my $op;
    foreach my $operand (keys %{$operators})
    {
      if ($arg eq $operand)
      {
        $op = $operand;
        last;
      }
    }
    if ($arg !~ /^_?[0-9\.]+$/ && !defined $op)
    {
      return 'Malformed or unknown argument: `' . $arg . '`, operators and operands must be separated';
    }
    elsif ($arg =~ /^_[0-9\.]+$/)
    {
      $arg =~ s/_/-/g;
    }
  }

  my $result = eval
  {
    while (@stack > 1)
    {
      my $op;
      for (my $i = 0; $i < @stack && !defined $op; $i++)
      {
        foreach my $operator (keys %{$operators})
        {
          if ($operator eq $stack[$i])
          {
            $op = $i;
            last;
          }
        }
      }

      return 'Malformed expression: missing operator.' if (!defined $op);
      my $num = $operators->{$stack[$op]}->{ops};
      if ($op < $num)
      {
        return 'Malformed expression: not enough arguments, expected ' . $num . '.';
      }

      if ($operators->{$stack[$op]})
      {
        if ($stack[$op] eq '/' && $stack[$op - 1] == 0) # manually test div/0
        {
          return 'Error: div/0';
        }
        my @ops;
        for (my $x = $num; $x >= 1; $x--)
        {
          push(@ops, $stack[$op - $x]);
        }
        $stack[$op - $num] = $operators->{$stack[$op]}->{fn}(@ops);
        splice(@stack, $op - ($num - 1), $num);
      }
      else # should never happen
      {
        return 'Uknnown operator: ' . $stack[$op];
      }
    }
    return $stack[0];
  };

  if ($@)
  {
    print STDERR 'ERROR: ' . $@ . "\n";
    return 'ERROR: ' . $@ . '.';
  }
  else
  {
    $last = $result;
    return 'Result: ' . $result;
  }
}

sub help
{
  return '!rpn (expr|list) - RPN calculator, expr is what you want to calculate. Use `!rpn list` to get a list of operators. Use _ for negatives. Operatives must be separated by spaces. Example use: !rpn 5 4 +';
}

sub auth
{
  return accessLevel('normal');
}

BobboBot::module::addCommand('rpn', 'run', \&BobboBot::rpn::run);
BobboBot::module::addCommand('rpn', 'help', \&BobboBot::rpn::help);
BobboBot::module::addCommand('rpn', 'auth', \&BobboBot::rpn::auth);

1;
