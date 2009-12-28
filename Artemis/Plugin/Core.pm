package Artemis::Plugin::Core;
use Digest::SHA qw(sha1_base64);
sub new{
	my $class = shift;
	my $self = {
		commands =>{
test => sub{return "Test passed!"},
say => sub{return shift if defined pop->level},
quit => sub{return if pop->level<=500;pop->disconnect()},
load => sub{return if pop->level<=500;return "Success" if pop->{main}->load(shift);return "Failure"},
quote => sub{my($a,$s,$c,$m)=@_;return if $m->level<=500;my($ind,$raw)=split(/ +/,$a,2);if(0+$ind eq $ind){$c->{main}{connections}[$ind]->send($raw)}else{$c->send($ind." ".$raw)}},
login => sub{my($a,$s,$c,$m)=@_;my($login,$pass)=split(/ +/,$a,2);return "UTTER FAILURE" if $c->{main}{pass}{$login} ne sha1_base64($pass);return "You are now logged in as ".($c->{main}{logins}{lc $m->token}=$login)},
mkuser => \&mkuser,
rmuser => sub{;},
passwd => \&passwd,
'eval' => sub{my($a,$s,$c,$m)=@_;return unless $m->level>500;return eval($a) || $@;},
whoami => sub{my $msg = pop;return $msg->user.", you are ".(defined($msg->level)?"logged in":"not logged in").", and as such your level is ".$msg->level},
gettoken => sub{my $msg = pop;return $msg->user.", your token is '".$msg->token."'"},
time => sub{return scalar localtime()},
timer => sub{my($a,$s,$c,$m)=@_;$s->{timers}{time()+$a}=[$c,$m];return "Timer added."},
		},
		timers => {},
	};
	return bless($self,$class);
}
sub Process{
	my $self = shift;
	for my $timer (keys %{$self->{timers}}){
		my($conn,$msg) = @{$self->{timers}{$timer}};
		if($timer <= time){
			$conn->message($msg->to,$msg->user.", your timer has expired.");
			delete($self->{timers}{$timer});
		}
	}
}
sub mkuser{
	my($input,$self,$conn,$msg)=@_;
	return "You must construct additional pylons." unless defined $msg->level;
	my($login,$level,$pass)=split(/ +/,$input,3);
	return "You must spawn more overlords." unless $msg->level > $conn->{main}{users}{$login};
	$conn->{main}{pass}{$login}=sha1_base64($pass);
	$conn->{main}{users}{$login}=($msg->level < $level)?$msg->level-1:$level;
}
sub passwd{
	my($input,$self,$conn,$msg)=@_;
	return "You are not logged in, sorry." unless defined $msg->level;
	return("Hash for ".$msg->user." set to ".($conn->{main}{pass}{$msg->user}=sha1_base64($input)));
}
sub input{
	my $self = shift;
	my($conn,$msg) = @_;
	$conn->message($msg->to,":D") if $msg->text =~ /^botsnack$/i;
	return unless $msg->pm && $msg->text =~ /^([^ ]+) ?(.*?)$/;
	return if time - $self->{main}{floodprot}{$msg->token} < 4;
	$self->{main}{floodprot}{$msg->token}=time;
	my($cmd,$args)=($1,$2);
	$conn->message($msg->to,$self->{commands}{$cmd}($args,$self,$conn,$msg)) if ref($self->{commands}{$1}) eq "CODE";
}
1;
