package Artemis;
use Module::PluginFinder;
sub new{
	# a simple constructor...
	my $class = shift;
	# keep an array of Artemis::Connection::* types in connections, a DBI handle in facts, and leave room for setting these at creation-time
	my $self = {connections=>[],facts=>undef,@_};
	# two arg bless. no clue why, but w/e.
	return bless($self,$class);
}
sub connect{
	# so things don't explode if somone stupid does Artemis::connect(); hopefully.
	my $self = shift if ref($_[0]);
	# a fairly generic Module::PluginFinder setup, from what I can tell...
	my $finder = Module::PluginFinder->new(
		search_path => 'Artemis::Connection',
		filter => sub {
			my ( $module, $searchkey ) = @_;
			$module->can( $searchkey );
		},
	);
	# so that multiple things can be connected to at once. magical, no?
	for(@_){
		# called like $art->connect({...}); not $art->connect(...);
		next unless ref($_) eq "HASH";
		eval{
			my $conn = $finder->construct($_->{type},%$_);
			push @{$self->{connections}}, $conn if $conn;
		};
		warn $@ if $@;
	}
}
# simply call $obj->Process() for each connection.
sub Process{
	my $self = shift;
	for my $conn (@{$self->{connections}}){
		print STDERR "Not blocking: ",time,"\n";
		$conn->Process(0);
	}
}
1;
