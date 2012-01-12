package Artemis::Plugin::Calc;
use Math::Complex;
use Math::Trig;
#use Inline::Python qw(py_eval py_bind_class py_call_function);
sub new{
	my $class =shift;
#	{
#		local $/;
#		open(my $x,"<","Artemis/Plugin/EnhancedCalc.py") or die 'Cant find my precious python file.';
#		my $y = <$x>;
#		py_eval($y);
#		close $x;
#	}
	return bless([],$class);
};

sub input{
	my $self = shift;
	my($conn,$msg) = @_;
	return unless $msg->pm;
	return if time - $conn->{main}{floodprot}{$msg->token} < 2;
	$conn->{main}{floodprot}{$msg->token}=time;
	if($msg->text =~ /^(p?)([bho]?)calcp? (.*)$/){
		my @stack = ();
		my @stackstack = ();
		my $memory = 0;
		my $binary = $2 eq "b";
		my $octal = $2 eq "o";
		my $hex = $2 eq "h";
		undef $@;
		my @ops = ($1 eq "p")?(reverse split ' ',$3):split ' ',$3;
		return $conn->message($msg->to,"PyEval Error: $@") if $@;
		for(@ops){
			push @stack,oct($_) and next if /^0[0-7]+?$/;
			push @stack,oct($_) and next if /^0b[01]+?$/;
			push @stack,oct($_) and next if /^0x?[0-9a-f]+?$/i;
			if(my@x=/^(\d+)d([\d%]+)$/){$x[1]=100if$x[1]eq"%";$x[0]=256if$x[0]>256;push@stack,$x[1]?int(rand$x[1])+1:0 while$x[0]--}
			if(/^(\d+)d[Ff]$/){my$x=$1;$x=256if$x>256;push@stack,(-1,0,1)[rand(3)]while$x--}
			{"+"=>sub{$_[1]+=$_[0]},"-"=>sub{$_[1]-=$_[0]}}->{$1}(($2/100)*$stack[-1],$stack[-1]) xor next if /^([\+\-])(\d+(\.\d+)?)\%/ && scalar(@stack)>0;
			push @stack,(0+$_)/(($2 eq "%")?100:1) and next if /^[-+]?\d+(\.\d+)?(%)?$/;
			push @stack,0+$_ and next if /^[-+]?\.\d+$/;
			push @stack,0+$_ and next if /^[-+]?\d+(\.\d+)?e\d+(\.\d+)?$/;
			$_=lc$_;
			if(exists($op{$_})){
				undef $@;
				eval{$op{$_}->(\@stack,\$memory)} if ref $op{$_} eq "CODE";
				return $conn->message($msg->to,"Error: Stack Underflow.") if $@ =~ /^Modification of non-creatable array value/;
				return $conn->message($msg->to,"Error: Universe imploded (Can't divide by zero)") if $@ =~ /^Illegal division by zero/;
				return $conn->message($msg->to,"Error: $@") if $@;
				push @stack, $op{$_} if ref $op{$_} eq "";
			}elsif($_ eq "("){
				push @stackstack, [@stack];
			}elsif($_ eq ")"){
				my $retval = pop @stack;
				@stack = @{pop @stackstack};
				push @stack, $retval;
			}
		}
		if($binary){
			local $_;
			$conn->message($msg->to,$msg->user.": ".join(",",map{sprintf("0b%b",$_)}@stack));
		}elsif($octal){
			local $_;
			$conn->message($msg->to,$msg->user.": ".join(",",map{sprintf("0%o",$_)}@stack));
		}elsif($hex){
			local $_;
			$conn->message($msg->to,$msg->user.": ".join(",",map{sprintf("0x%x",$_)}@stack));
		}else{
			$conn->message($msg->to,$msg->user.": ".join(",",@stack));
		}
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
'<=>' => sub{$_[0][-1]=$_[0][-2]<=>pop @{$_[0]}},
# section 2: constants
'inf' => inf,
'nan' => NaN,
'pi' => pi,
'e' => exp(1),
'i' => sub{push@{$_[0]},sqrt(-1)},
'porn' => 5318008,
# section 3: unary ops
'sqrt' => sub{$_[0][-1] = sqrt($_[0][-1])},
'sin' => sub{$_[0][-1] = sin($_[0][-1])},
'cos' => sub{$_[0][-1] = cos($_[0][-1])},
'tan' => sub{$_[0][-1] = tan($_[0][-1])},
'~' => sub{$_[0][-1] = ~$_[0][-1]},
'ln' => sub{$_[0][-1] = $_[0][-1] != 0?log $_[0][-1]:-inf},
'log' => sub{$_[0][-1] = $_[0][-1] != 0?log($_[0][-1])/log(10):-inf},
'1/x' => sub{$_[0][-1] = 1/$_[0][-1]},
'exp' => sub{$_[0][-1] = exp $_[0][-1]},
'rnd' => sub{$_[0][-1] = rand $_[0][-1]},
'int' => sub{$_[0][-1] = int $_[0][-1]},
'!' => sub{$_[0][-1] = $_[0][-1]?0:1},
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
'sum' => sub{while(@{$_[0]}>1){$_[0][0]+=pop@{$_[0]}}},
'product' => sub{$_[0][0]||=1;while(@{$_[0]}>1){$_[0][0]*=pop@{$_[0]}}},
'cls' => sub{@{$_[0]}=()},
'sort>' => sub{@{$_[0]}=sort{$b<=>$a}@{$_[0]}},
'sort<' => sub{@{$_[0]}=sort{$a<=>$b}@{$_[0]}},
);
1;
