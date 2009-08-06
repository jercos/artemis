package Artemis::Plugin::Calc;
use Math::Complex;
use Math::Trig;
sub new{
	my $class =shift;
	return bless([],$class);
};

sub input{
	my $self = shift;
	my($conn,$msg) = @_;
	if($msg->text =~ /^calc (.*)$/){
		my @stack = ();
		my $memory = 0;
		my @ops = split ' ',$1;
		for(@ops){
			push @stack,oct($_) and next if /^0[0-7]+?$/;
			push @stack,oct($_) and next if /^0b[01]+?$/;
			push @stack,oct($_) and next if /^0x?[0-9a-f]+?$/;
			push @stack,0+$_ and next if /^-?\d+(\.\d+)?$/;
			$_=lc$_;
			if(exists($op{$_})){
				undef $@;
				eval{$op{$_}->(\@stack,\$memory)} if ref $op{$_} eq "CODE";
				return $conn->message($msg->to,"Error: $@") if $@;
				push @stack, $op{$_} if ref $op{$_} eq "";
			}
		}
		$conn->message($msg->to,"Returned ".join(",",@stack));
	}
};

%op=(
# section 1: binops
'+' => sub{$_[0][-2] += pop @{$_[0]}},
'-' => sub{$_[0][-2] -= pop @{$_[0]}},
'*' => sub{$_[0][-2] *= pop @{$_[0]}},
'/' => sub{$_[0][-2] /= pop @{$_[0]}},
'\\' => sub{$_[0][-1] = int($_[0][-2] / pop @{$_[0]})}, # integer division. Just like BASIC?
'%' => sub{$_[0][-2] %= pop @{$_[0]}},
'**' => sub{$_[0][-2] **= pop @{$_[0]}},
'^' => sub{$_[0][-2] ^= pop @{$_[0]}},
'&' => sub{$_[0][-2] &= pop @{$_[0]}},
'|' => sub{$_[0][-2] |= pop @{$_[0]}},
'x' => sub{@{$_[0]}[-1,-2] = @{$_[0]}[-2,-1]}, # swap the top two.
# section 2: constants
'inf' => inf,
'nan' => NaN,
'pi' => pi,
'e' => exp(1),
'i' => sub{push@{$_[0]},sqrt(-1)},
# section 3: unary ops
'sqrt' => sub{$_[0][-1] = sqrt($_[0][-1])},
'sin' => sub{$_[0][-1] = sin($_[0][-1])},
'cos' => sub{$_[0][-1] = cos($_[0][-1])},
'tan' => sub{$_[0][-1] = tan($_[0][-1])},
'~' => sub{$_[0][-1] = ~$_[0][-1]},
'ln' => sub{$_[0][-1] = log $_[0][-1]},
'log' => sub{$_[0][-1] = log($_[0][-1])/log(10)},
'1/x' => sub{$_[0][-1] = 1/$_[0][-1]},
'exp' => sub{$_[0][-1] = exp $_[0][-1]},
'rnd' => sub{$_[0][-1] = rand $_[0][-1]},
'int' => sub{$_[0][-1] = int $_[0][-1]},
# section 4: weird stuff
'time' => sub{push@{$_[0]},time}, # it's not constant, but it's not an operator.
'rand' => sub{push@{$_[0]},rand},
'_' => sub{push@{$_[0]},$_[0][-1]},
'@' => sub{pop@{$_[0]}},
'mc' => sub{${$_[1]}=0},
'mr' => sub{push@{$_[0]},${$_[1]}},
'm+' => sub{${$_[1]}+=pop@{$_[0]}},
'm-' => sub{${$_[1]}-=pop@{$_[0]}},
'mx' => sub{($_[0][-1],${$_[1]}) = (${$_[1]},$_[0][-1])}, # swap memory and the top
'r^' => sub{push@{$_[0]},shift@{$_[0]}},
'rv' => sub{unshift@{$_[0]},pop@{$_[0]}},
);
1;
