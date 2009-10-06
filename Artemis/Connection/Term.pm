package Artemis::Connection::Term;
use Term::ReadKey;
use strict;
sub new{
	my $class = shift;
	my $self = {
		sock=>undef,
		level=>65536,
		nick=>"artemis",
		@_
	};
	bless($self,$class);
	return $self;
}

sub connect{
	my $self = shift;
	print "Connecting\n";
	return unless defined($self->{sock});
}

sub disconnect{
	my $self = shift;
	return unless defined($self->{sock});
}

sub Process{
	my $self = shift;
	my $input;
	if(defined $self->{sock}){
		$input = ReadLine(-1,$self->{sock});
	}else{
		$input = ReadLine(-1);
	}
	$input =~ s/[\r\n]//g;
	return unless $input;
	$self->{main}->incoming($self,Artemis::Message->new(level=>$self->{level},user=>"cons",to=>"cons",text=>$input,pm=>1));
}

sub send{
	my $self = shift;
	print "$_\n" for @_;
}

sub message{
	my $self = shift;
	my($to,$msg) = @_;
	$self->send("$to: $msg");
}

sub term{

}
1;
