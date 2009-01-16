package Artemis::Plugin::Core;
sub new{
	my $class = shift;
	my $self = {
		test => sub{return "Tested true. Yay!"},
	};
	return bless($self,$class);
}
sub message{
	my $self = shift;
	my $msg = shift;
	my $pm = shift;
	return unless $msg =~ /^\)([^ ]*)/;
	return &{$self->{$1}}() if exists $self->{$1};
	0;
}
1;
