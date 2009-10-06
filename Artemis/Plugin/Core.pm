package Artemis::Plugin::Core;
use Digest::SHA qw(sha1_base64);
sub new{
	my $class = shift;
	my $self = {
		commands =>{
test => sub{return "Test passed!"},
say => sub{return shift},
quit => sub{return if pop->level<=500;pop->disconnect()},
load => sub{return if pop->level<=500;return "Success" if pop->{main}->load(pop);return "Failure"},
quote => sub{return if pop->level<=500;my($ind,$raw)=split(/ +/,shift,2);if(0+$ind eq $ind){shift->{main}{connections}[$ind]->send($raw)}else{shift->send($ind." ".$raw)}},
login => sub{my($login,$pass)=split(/ +/,shift,2);my $conn = shift;return "UTTER FAILURE" if $conn->{main}{pass}{$login} ne sha1_base64($pass);return "You are now logged in as ".($conn->{main}{logins}{lc pop->token}=$login)},
mkuser => \&mkuser,
rmuser => sub{;},
'eval' => sub{return unless pop->level>500;return eval(shift) || $@;},
whoami => sub{my $msg = pop;return $msg->user.", you are ".(defined($msg->level)?"logged in":"not logged in").", and as such your level is ".$msg->level},
gettoken => sub{my $msg = pop;return $msg->user.", your token is '".$msg->token."'"},
time => sub{return scalar localtime()},
		}
	};
	return bless($self,$class);
}
sub mkuser{
	my($input,$conn,$msg)=@_;
	return "You must construct additional pylons." unless defined $msg->level;
	my($login,$level,$pass)=split(/ +/,$input,3);
	return "You must spawn more overlords." unless $msg->level > $conn->{main}{users}{$login};
	$conn->{main}{pass}{$login}=sha1_base64($pass);
	$conn->{main}{users}{$login}=($msg->level < $level)?$msg->level-1:$level;
}
sub input{
	my $self = shift;
	my($conn,$msg) = @_;
	return unless $msg->pm && $msg->text =~ /^([^ ]+) ?(.*?)$/;
	return if time - $self->{main}{floodprot}{$msg->token} < 4;
	$self->{main}{floodprot}{$msg->token}=time;
	my($cmd,$args)=($1,$2);
	$conn->message($msg->to,":D") if $msg->text =~ /^botsnack/i;
	$conn->message($msg->to,$self->{commands}{$cmd}($args,$conn,$msg)) if ref($self->{commands}{$1}) eq "CODE";
}
1;
