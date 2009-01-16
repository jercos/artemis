package Artemis::Plugin::Core;
sub new{
	my $class = shift;
	my $self = {
		test => sub{return "Tested true. Yay!"},
	};
	return bless($self,$class);
}
sub input{
	my $self = shift;
	my($conn,$to,$name,$msg,$pm) = @_;
	return unless $msg =~ /^\)([^ ]*)(.*)/;
	$conn->message($to,$self->{$1}($2)) if exists $self->{$1} && ref($self->{$1}) eq "CODE";
	0;
}
1;
