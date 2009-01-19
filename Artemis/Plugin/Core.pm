package Artemis::Plugin::Core;
sub new{
	my $class = shift;
	my $self = {
		test => sub{return "Tested true. Yay!"},
		say => sub{return shift},
		quit => sub{my($msg, $conn)=@_;$conn->disconnect()},
	};
	return bless($self,$class);
}
sub input{
	my $self = shift;
	my($conn,$to,$name,$msg,$pm) = @_;
	my $nick = $conn->{nick};
	print "Core was called\n";
	return unless $msg =~ /^\)([^ ]+) ?(.*?)$/ || $msg =~ /^$nick[ :,]+([^ ]+) ?(.*?)$/i;
	$conn->message($to,$self->{$1}($2,$conn)) if exists $self->{$1} && ref($self->{$1}) eq "CODE";
}
1;
