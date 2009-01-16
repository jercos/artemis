package Artemis::Plugin::Core;
sub new{
	my $class = shift;
	my $self = {};
	return bless($self,$class);
}
sub message{
	my $self = shift;
	my $msg = shift;
	print "Core got '$msg', returning it\n";
	return $msg;
}
1;
