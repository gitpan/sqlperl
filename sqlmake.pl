#!/usr/bin/perl -s 

&initialize;
&doExit;

#--------------------------------------------------------------------------

sub initialize
{
	open(IN,'sqlpl.bin') || die " u:Could not open input file!";
	while (<IN>)
	{
		chomp;
		($dbtable,@users) = split(/,/);
		push (@dbtables,$dbtable);
		$users = join(',',@users);
		push (@dbusers,$users);
	}
	close IN;
}

sub doExit
{
	my ($u, @users);

	open (OUT,'>sqlpl.dat') || die " u:Could not open sqlpl.dat ($? $@)";
	for (0..$#dbtables)
	{
		#$dbtables[$_] =~ s/\://;
		$salt = substr($dbtables[$_],0,2);
		@users = split(/,/,$dbusers[$_]);
print "--table=$dbtables[$_]= salt=$salt=\n";
		print OUT $dbtables[$_];
		foreach $u (@users)
		{
print "-------crypting user=$u=";
			print OUT ' ', crypt($u,$salt);
			print " str=", crypt($u,$salt),"=\n";
		}
		print OUT "\n";
	}
	exit(0);
}
