package Artemis::Message;
sub new{
	my $class = shift;
	my $self = {
		text=>undef,
		to=>undef,
		via=>undef,
		user=>undef,
		pm=>0,
		level=>0,
		token=>"null://",
		nick=>"artemis",
		@_
	};
	if($self->{text}=~s/(\)|($self->{nick})[, :]+)// || $self->{via} eq $self->{nick}){
		$self->{pm}=1;
	}
	return bless($self, $class);
}
sub text{
	my $self = shift;
	if(@_){$self->{text}=shift;return $self}
	return $self->{text};
}
sub to{
	my $self = shift;
	if(@_){$self->{to}=shift;return $self}
	return $self->{to};
}
sub via{
	return shift->{at};
}
sub user{
	return shift->{user};
}
sub level{
	return shift->{level};
}
sub token{
	return shift->{token};
}
sub pm{
	my $self = shift;
	if(@_){$self->{pm}=!(!shift);return $self}
	return $self->{pm};
}
1
