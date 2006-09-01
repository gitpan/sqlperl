#!/usr/bin/perl -s 

#use lib '.';
#STRIP OUT INC PATHS USED IN COMPILATION - COMPILER PUTS EVERYTING IN IT'S OWN
#TEMPORARY PATH AND WE DONT WANT THE RUN-TIME PHISHING AROUND THE USER'S LOCAL
#MACHINE FOR (POSSIBLY OLDER) INSTALLED PERL LIBS (IF HE HAS PERL INSTALLED)!
BEGIN
{
	if ($0 =~ /exe$/i)
	{
		while (@INC)
		{
			$_ = shift(@INC);
			push (@myNewINC, $_) if (/(?:cache|CODE)/);
		}
		@INC = @myNewINC;
	}
}

#NOTE: Windows compile:  perl2exe [-gui] -perloptions="-p2x_xbm -s" yourscript.pl

#	perl2exe_include Tk/balArrow.xbm
#	perl2exe_include Tk/cbxarrow.xbm

$showgrabopt = '';
$showgrabopt = '-nograb';   #UNCOMMENT IF YOU HAVE MY LATEST VERSION OF JDIALOG!

#BEGIN { $ENV{DBI_PUREPERL} = 2 };
print "-using DBI::PurePerl!\n"  if ($ENV{DBI_PUREPERL});

use Text::Wrap;
#LOAD ORAPERL (DBI) STUFF-----

$| = 1;
$newwhere = 1;

#$dbi_err = \$DBI::err;
#$dbi_errstr = \$DBI::errstr;

#eval 'use Oraperl; 1' || die $@ if $] >= 5;
#require "OraPerl.ph";
require "setPalette.pl";
eval 'use File::Spec::Win32; 1';
eval 'use File::Glob; 1';
use DBI;
eval 'use DBD::Proxy; 1';
eval 'use DBD::ODBC; 1';
eval 'use DBD::Oracle; 1';
eval 'use DBD::Sprite; 1';
eval 'use DBD::LDAP; 1';
eval 'use RPC::PlClient; 1';
$noexcel = 1;
eval 'use Spreadsheet::WriteExcel; $noexcel = 0; 1';
$noexcelin = 1;
eval 'use Spreadsheet::ParseExcel::Simple; $noexcelin = 0; 1';
$noxml = 1;
#eval 'use XML::Generator::DBI; use XML::Handler::YAWriter; $noxml = 0; 1';
eval 'require MIME::Base64; $noxml = 0; 1';
$newfmt = 0;
#eval 'use Text::Autoformat (form); $newfmt = 1; 1';   #THIS THING AINT READY FOR PRIME TIME!!!!!!!!!!!!!!!!!!
#####eval 'require "BindMouseWheel.pl"; $WheelMouse = 1; 1';

#-----------------------

use Tk;                   #LOAD TK STUFF
use Tk::Radiobutton;
use Tk::Checkbutton;
use Tk::ROText;
use Tk::JDialog;
use Tk::JFileDialog;
use Tk::JBrowseEntry;
use Tk::JOptionmenu;

#require 'getopts.pl';
require 'JCutCopyPaste.pl';

$| = 1;

$dbname = '';
%themeCodeHash = ();
%dbthemes = ();
%dbtypes = ();
%precmds = ();
%attbs = ();
$preStatus = '';

#$os = 'WINDOWS NT'  unless (defined $os);
#$os = 'UNIX'  unless (defined $os);
$os = $^O;

$browser ||= 'start'  if ($os =~ /Win/i);
$dbtype = 'Oracle'  unless (defined $dbtype);

$pgmhome = $0;
#$pgmhome =~ s#sql\.pl[^/]*$##;
$pgmhome =~ s#sql[^/]*$##;  #SET NAME TO SQL.PL FOR ORAPERL!
print "-pgmhome=$pgmhome=\n";
&loadBrowseChoices;

if ($os =~ /Win/i)
{
	$fixedfont = '-*-lucida console-medium-r-normal-*-17-*-*-*-*-*-*-*'; #NT: PC-SPECIFIC.
	$osslash = "\\";
}
elsif ($os =~ /x|solaris/)
{
	#$fixedfont = '-b&h-lucidatypewriter-medium-r-normal-sans-17-120-100-100-m-100-iso8859-1'; #UNIX-SPECIFIC.
	$fixedfont = '-b&h-lucidatypewriter-medium-r-normal-sans-14-100-100-100-m-80-iso8859-1';
	$osslash = '/';
}
else
{
	$fixedfont = '-*-courier-medium-r-normal-*-17-*-*-*-*-*-*-*'; #Win-95: PC-SPECIFIC.
	$osslash = '/';
}

$oplist = ['=','!=','like','not like','<','>','<=','>=','is','is not','in'];
#$oplist = ['=','!=','like','not like','<','>','<=','>=','is','is not','=~','!~']  if ($sprite);

#if ($ARGV[0]) #ALLOWS COMMAND-LINE OF DB INFO (sql.pl dbname dbuser dbpswd)
if (0)        #WE NO LONGER ALLOW COMMAND-LINE ENTRY FOR SECURITY REASONS :-(
{
	$dbname = $ARGV[0] || '';
	$dbuser = $ARGV[1] || '';
	$dbpswd = $ARGV[2] || '';
	@dbname = split(/:/,$dbname);
	$dbname = 'T:' . $dbname  if ($#dbname == 1);

	&dbconnect();

	$didlogin = 0;
    #$didlogin = 1  if ($$dbi_err == 0);
	$didlogin = 1  unless (DBI->err);
#$didlogin = 1;
	&mainstuff  if ($didlogin);
	&exitFn();
	exit (0);
}

my $vsn = '4.8';
my $headTitle = 'SqlPerl Plus, v. '.$vsn;
my $helpurl = 'http://home.mesh.net/turnerjw/jim/sqlperl.html';
my ($OK, $Cancel) = ('~OK', '~Cancel');

&loginWindow();
#MainLoop;

sub loginWindow
{
	$MainWin->destroy  if ($MainWin);
	$dB->disconnect  if ($dB);

	$MainWin = MainWindow->new;
$MainWin->title($headTitle);

#FETCH ANY USER-SPECIFIC OPTIONS FROM sql.ini:

	$_ = $0;
	s/(\w+)\.\w+$/$1\.ini/g;
	if (open PROFILE, $_)
	{
		while (<PROFILE>)
		{
			chomp;
			s/[\r\n\s]+$//;
			s/^\s+//;
			next  if (/^\#/);
			($opt, $val) = split(/\=/, $_, 2);
			${$opt} = $val  if ($opt);
		}
		close PROFILE;
	}

	$c = $palette  if ($palette);
	unless ($c)
	{
		if ($os =~ /Win/i)
		{
			if (open (T, ".Xdefaults") || open (T, "$ENV{HOME}/.Xdefaults")
				|| open (T, "${pgmhome}Xdefaults") || open (T, "/etc/Xdefaults"))
			{
				while (<T>)
				{
					chomp;
					if (/tkPalette\s*\=\s*\"([^\"]+)\"/)
					{
						$c = $1;
						last;
					}
				}
			}
		}
		else
		{
			eval { $MainWin->optionReadfile('~/.Xdefaults') or $MainWin->optionReadfile('/etc/Xdefaults'); };
			$c = $MainWin->optionGet('tkPalette','*');
		}
	}
	$MainWin->setPalette($c)  if ($c);
	$listheight = $lh || 8;
	$msgheight = $mh || 8;
	$sqlheight = $sh || 3;
	$fmtmax = $fmt || 6;

	$topLabel = $MainWin->Label(-text => 'Log onto desired database:');
	$topLabel->pack(
			-fill	=> 'x',
			-expand	=> 'yes',
			-padx	=> '2m',
			-pady	=> '2m');

	$bottomFrame = $MainWin->Frame;
	$lognbtnFrame = $bottomFrame->Frame;
	$lognlbl = $bottomFrame->Frame;
	$lognlbl->pack(
			-side	=> 'top',
			-fill   => 'x',
			-padx   => '2m',
			-pady   => '2m');
	$lognbtnFrame->pack(
			-side	=> 'bottom',
			-fill   => 'x',
			-padx   => '2m',
			-pady   => '2m');
	$sysidFrame = $bottomFrame->Frame;
	$sysidFrame->pack(
			-side	=> 'left',
			-fill   => 'x',
			-padx   => '2m',
			-pady   => '2m');
	$dbnameFrame = $bottomFrame->Frame;
	$dbnameFrame->pack(
			-side	=> 'left',
			-fill   => 'x',
			-padx   => '2m',
			-pady   => '2m');
	$pswdFrame = $bottomFrame->Frame;
	$pswdFrame->pack(
			-side	=> 'left',
			-fill   => 'x',
			-padx   => '2m',
			-pady   => '2m');

	$sysidLabel = $sysidFrame->Label(-text => 'Database');
	$sysidLabel->pack(-side => 'top',
			-fill => 'x',
			-padx=>'2m');
	$sysidText = $sysidFrame->JBrowseEntry(
			-btntakesfocus => 0,
			-variable => \$dbname,
			-browsecmd => sub { $dbtype = $dbtypes{$dbname}  if ($dbtypes{$dbname}) },
			-width  => 12);
	$sysidText->pack(
			-side   => 'bottom',
			-expand => 'yes',
			-padx   => '2m',
			-pady   => '2m',
			-fill   => 'x');

	$dbnameLabel = $dbnameFrame->Label(-text => 'User');
	$dbnameLabel->pack(-side => 'top',
			-fill => 'x',
			-padx=>'2m');
#$dbnameText = $dbnameFrame->Entry(
#	-relief => 'sunken',
#	-width  => 12);
	$dbnameText = $dbnameFrame->JBrowseEntry(
			-btntakesfocus => 0,
			-variable => \$dbuser,
			-browsecmd => sub { $dbtype = $dbtypes{$dbuser}  if ($dbtypes{$dbuser}) },
			-width  => 12);
	$dbnameText->pack(
			-side   => 'bottom',
			-expand => 'yes',
			-padx   => '2m',
			-pady   => '2m',
			-fill   => 'x');
#NEXT LINE ADDED 20040819 TO ALLOW CAPTURE OF DBNAME FOR COPYING TO PASSWORD.
	$dbnameText->bind('<FocusOut>' => sub {$MainWin->clipboardAppend('--',$dbuser);});
	$pswdLabel = $pswdFrame->Label(-text => 'Password');
	$pswdLabel->pack(-side => 'top',
			-fill => 'x',
			-padx => '2m');
	$pswdText = $pswdFrame->Entry(
			-show	=> '*',
			-relief => 'sunken',
			-width  => 12);
	$pswdText->pack(
			-side   => 'bottom',
			-expand => 'yes',
			-padx   => '2m',
			-pady   => '2m',
			-fill   => 'x');

	$lognokButton = $lognbtnFrame->Button(
			-padx => 11,
			-pady =>  4,
			-text => 'Ok',
			-underline => 0,
			-command => [\&dologin]);
	$lognokButton->pack(-side=>'left', -expand=>1, -padx=>'2m', -pady=>'2m');

	$logncanButton = $lognbtnFrame->Button(
			-padx => 11,
			-pady =>  4,
			-text => 'Exit',
			-underline => 0,
			-command => [\&exit]);
	$logncanButton->pack(-side=>'left', -expand=>1, -padx=>'2m', -pady=>'2m');

	$lognHelpButton = $lognbtnFrame->Button(
			-padx => 11,
			-pady =>  4,
			-text => 'Help',
			-underline => 0,
			-command => [\&About]);
	$lognHelpButton->pack(-side=>'left', -expand=>1, -padx=>'2m', -pady=>'2m');


	$bottomFrame2 = $MainWin->Frame;

#$dbtypeLabel = $bottomFrame2->Label(
#		-text => 'Database Type: ');
#$dbtypeLabel->pack(-side => 'left');

	my (@dbidrivers) = DBI->available_drivers();
	my (%dbidrivers);
	foreach my $i (@dbidrivers, qw(Sprite mysql Oracle ODBC LDAP))
	{
		++$dbidrivers{$i};
	}
	$dbtypeOpMenu = $bottomFrame2->JBrowseEntry(
			-label => 'Database Type',
			-variable => \$dbtype,
			-state => 'readonly',
			#-tabcomplete => 1,
			#-noselecttext => 1,
			-width => 12,
			-choices => [sort keys(%dbidrivers)]);
	$dbtypeOpMenu->pack(-side => 'left');

	$attbFrame = $MainWin->Frame;
	$attbLabel = $attbFrame->Label(-text => 'Attributes:');
	$attbLabel->pack(-side => 'left');
	$attbText = $attbFrame->Entry(
			-relief => 'sunken',
			-width  => 40);
	$attbText->pack(
			-side   => 'left',
			-expand => 'yes',
			-padx   => '2m',
			-pady   => '2m',
			-fill   => 'x');

	$bottomFrame3 = $MainWin->Frame;
	$rhostLabel = $bottomFrame3->Label(
			-text => 'Remote Host:port');
	$rhostLabel->pack(-side => 'left');
	$rhostEntry = $bottomFrame3->JBrowseEntry(
			-btntakesfocus => 0,
			-variable => \$rhost,
			-width  => 40)
			->pack(
			-side   => 'left',
			-padx   => '1m',
			-pady   => '4m');

	$statusFrame = $MainWin->Frame;
	$statusText = $statusFrame->ROText(
			-width => $msgheight,
			-height => 4);
	$statusText->bind('<FocusIn>' => [\&textfocusin]);
	&BindMouseWheel($statusText)  if ($WheelMouse);
	$statusScrollY = $statusFrame->Scrollbar(
			-relief => 'sunken',
			-orient => 'vertical',
			-command=> [$statusText => 'yview']);
	$statusText->configure(-yscrollcommand=>[$statusScrollY => 'set']);
	$statusScrollY->pack(
			-side   => 'right',
			-fill   => 'y');
	$statusText->pack(
			-side   => 'top',
			-expand => 'yes',
			-fill   => 'both');
##	tie (*STDERR, 'Tk::ROText', $statusText);   #ADDED 20000224 SO I CAN SEE ERRORS!  REMOVED 20060512 (STDERR PRODUCED TOO MUCH NOISE!)
	$statusText->see('end');

	$statusFrame->pack(
			-side	=> 'bottom',
			-expand	=> 'yes',
			-fill	=> 'both');
	$bottomFrame->pack(-side => 'top');
	$bottomFrame3->pack(-side => 'bottom');
	$attbFrame->pack(-side => 'bottom');
	$bottomFrame2->pack(-side => 'bottom');

	my $foundAlready = 0;
	for ($i=0;$i<=$#dbnames;$i++)
	{
		$sysidText->insert('end',$dbnames[$i]);
		$foundAlready = 1  if ($dbname && $dbnames[$i] eq $dbname);
	}
	unless ($foundAlready)
	{
		if ($dbname)
		{
			$sysidText->insert('end',$dbname);
			push (@dbnames, $dbname);
		}
	}
	$foundAlready = 0;
	for ($i=0;$i<=$#dbusers;$i++)
	{
		$dbnameText->insert('end',$dbusers[$i]);
		$foundAlready = 1  if ($dbuser && $dbusers[$i] eq $dbuser);
	}
	unless ($foundAlready)
	{
		if ($dbuser)
		{
			$dbnameText->insert('end',$dbuser);
			push (@dbusers, $dbuser);
		}
	}
	$foundAlready = 0;
	for ($i=0;$i<=$#rhosts;$i++)
	{
		$rhostEntry->insert('end',$rhosts[$i]);
		$foundAlready = 1  if ($rhost && $rhosts[$i] eq $rhost);
	}
	unless ($foundAlready)
	{
		if ($rhost)
		{
			$rhostEntry->insert('end',$rhost);
			push (@rhosts, $rhost);
		}
	}
	$sysidText->configure(-state => 'textonly')  unless ($#dbnames >= 0);
	$dbnameText->configure(-state => 'textonly')  unless ($#dbusers >= 0);
	$rhostEntry->configure(-state => 'textonly')  unless ($#rhosts >= 0);

	$MainWin->update;


	$logncanButton->bind('<Return>' => "Invoke");
	$lognokButton->bind('<Return>' => "Invoke");
#$MainWin->bind('<Alt-o>' => [$lognokButton => "Invoke"]);
#$MainWin->bind('<Alt-c>' => [$logncanButton => "Invoke"]);
	bind('<Escape>' => [$logncanButton => "Invoke"]);
#$dbtypeOpMenu->bind('<Return>' => sub {shift->PostFirst; Tk->break;});
#$dbtypeOpMenu->bind('<Return>' => [$lognokButton => "Invoke"]);
#$rhostEntry->bind('<Return>' => [$lognokButton => "Invoke"]);
####$MainWin->bind('<Return>' => [$lognokButton => "Invoke"]);
####$MainWin->bind('<Escape>' => [$logncanButton => "Invoke"]);
	$pswdText->bind('<Return>' => [$lognokButton => "Invoke"]);
	$pswdText->bind('<Escape>' => [$logncanButton => "Invoke"]);
	$attbText->bind('<Return>' => [$lognokButton => "Invoke"]);
	$attbText->bind('<Escape>' => [$logncanButton => "Invoke"]);
	$sysidText->focus;
	$sysidText->selectionRange(0,'end');
	$usefmt = 0;
	$newwhere = 1;

	MainLoop;
}



sub mainstuff
{
	$MainWin->destroy  if ($MainWin);
	$MainWin = MainWindow->new;
	$MainWin->setPalette($c)  if ($c);
	$mainTitle = "$headTitle (DBD $dbtype):  database:\"$rhostname$dbname\", user->$dbuser.";
	$MainWin->title($mainTitle);
	$orderSel = 'order';
	$use = 'line';
	$myfmt = '';

	my $w_menu = $MainWin->Frame(-relief => 'raised', -borderwidth => 2);
	$w_menu->pack(-fill => 'x');



	$fileMenubtn = $w_menu->Menubutton(-text => 'File', -underline => 0, -takefocus => 1);
	$fileMenubtn->command(-label => 'Alter table...', -underline =>0, -command => [\&altertable]);
	$fileMenubtn->command(-label => 'Break', -underline =>0, -command => sub {$abortit = 1;});
	$fileMenubtn->command(-label => 'Create(setup)',    -underline =>0, -command => [\&dodescribe,3]);
	$fileMenubtn->command(-label => 'Describe',    -underline =>0, -command => \&dodescribe);
	$fileMenubtn->command(-label => 'Edit',    -underline =>0, -command => \&editfid);
	$fileMenubtn->command(-label => 'Fields',    -underline =>0, -command => [\&dodescribe,2]);
	$fileMenubtn->command(-label => 'field Names',    -underline =>6, -command => [\&dodescribe,1]);
	$fileMenubtn->command(-label => 'Insert file',    -underline =>0, -command => [\&insertfile]);
	$fileMenubtn->command(-label => 'Load Columns', -underline =>0, -command => \&loadcols);
	$fileMenubtn->command(-label => 'Process SQL File', -underline =>0, -command => \&doprocess);  #ADDED 20030703.
	$fileMenubtn->command(-label => 'Xeq SQL File', -underline =>0, -command => \&doxeq);  #ADDED 20030703.
	$fileMenubtn->command(-label => 'Reload',    -underline =>0, -command => \&loadtable);
	$fileMenubtn->command(-label => 'Sprite',    -underline =>0, -command => \&doSprite);
	$fileMenubtn->command(-label => 'M$-Excel',    -underline =>1, -command => \&doExcel);
#	$fileMenubtn->cascade(-label => 'Use', -menuitems => [
	if ($#usedbs >= 0)
	{
		my @usemenuItems = ();
		my ($usedb, $usetheme);
		for (my $i=0;$i<=$#usedbs;$i++)
		{
			$usedb = $usedbs[$i];
			$usetheme = ($usedb =~ s/\:(.*)//) ? $1 : '';
			push (@usemenuItems, [Button => $usedb, -command => [\&doUseDB, $usedb, $usetheme]]);
		}
		$fileMenubtn->cascade(-label => 'Use', -menuitems => \@usemenuItems);
	}
	$fileMenubtn->command(-label => 'XML', -command => \&doXML);
	$fileMenubtn->entryconfigure('M$-Excel', -state => 'disabled')  if ($noexcel);
	$fileMenubtn->entryconfigure('XML', -state => 'disabled')  if ($noxml);
	$fileMenubtn->separator;
	$fileMenubtn->command(-label => 'Login New',    -underline =>0, -command => \&loginWindow);
	$fileMenubtn->command(-label => 'eXit',    -underline =>1, -command => \&exitFn);

	my $editMenubtn = $w_menu->Menubutton(-text => 'Edit', -underline => 0);
	$editMenubtn->command(-label => 'Clear', -underline =>4, -command => \&clearFn);
	$editMenubtn->separator;
	$editMenubtn->command(-label => 'Copy',  -underline =>0, -command => [\&doCopy]);
	$editMenubtn->command(-label => 'cuT',   -underline =>2, -command => [\&doCut]);
	$editMenubtn->command(-label => 'Paste (Clipboard)', -underline =>0, -command => [\&doPaste,'CLIPBOARD']);
	$editMenubtn->command(-label => 'Paste (Primary)',   -underline =>8, -command => [\&doPaste,'PRIMARY']);

	if (open (T, ".myethemes") || open (T, "$ENV{HOME}/.myethemes")
			|| open (T, "${pgmhome}myethemes"))
	{
		$themeMenuBtn = $w_menu->Menubutton(
				-text => 'Themes');
		my ($themename, $themecode);
		while (<T>)
		{
			chomp;
			($themename, $themecode) = split(/\:/);
			$themeCodeHash{$themename} = $themecode;
			eval "\$themeMenuBtn->command(-label => '$themename', -command => sub {&setTheme($themename);});";
		}
		close T;
	}
	my $globalUseThisTheme = $dbthemes{$dbuser} || $dbthemes{$dbname} || $dbthemes{$dbtype};
	&setTheme($globalUseThisTheme);
	$startfpath = $ENV{PWD} || $ENV{HOME};
	if (open (T, "$ENV{HOME}.sqlfpath.dat"))
	{
		$startfpath = <T>;
		chomp($startfpath);
		close T;
	}
	$startfpath = '.'  unless ($startfpath =~ /\S/);

	$commitMenubtn = $w_menu->Menubutton(-text => 'Commit', -underline => 0);
	$commitMenubtn->command(-label => 'Commit', -underline =>0, -command => [\&docommit]);
	$commitMenubtn->command(-label => 'Rollback', -underline =>0, -command => [\&dorollback]);
	$commitMenubtn->separator;
	$commitMenubtn->command(-label => 'Auto commit',  -underline =>0, -command => sub
	{
		$dB->{AutoCommit} = 1;
		$nocommit = 2;
		$commitButton->configure(-text => 'Autocommit', -state => 'disabled');
	}
	);
	$commitMenubtn->command(-label => 'Force commit', -underline =>0, -command => sub
	{
		$dB->{AutoCommit} = 0; #  unless $autocommit;
		$nocommit = 0;
		$commitButton->configure(-text => 'Committed', -state => 'disabled');
	}
	);
	$commitMenubtn->command(-label => 'Manual commit', -underline =>0, -command => sub
	{
		$dB->{AutoCommit} = 0; #  unless $autocommit;
		$nocommit = 1;
		$commitButton->configure(-text => 'COMMIT!', -state => 'normal');
	}
	);
	$commitMenubtn->configure(-state => 'disabled')  if ($autocommit);

	my $helpMenubtn = $w_menu->Menubutton(-text => 'help', -underline => 0);
	$helpMenubtn->command(-label => 'About', -underline =>0, -command => \&About);
	if ($browser)
	{
		$helpMenubtn->command(-label => 'Help', -underline =>0, -command => sub
		{
			system($browser, $helpurl);
		}
		);
	}

	$fileMenubtn->pack(-side=>'left');
	$editMenubtn->pack(-side=>'left');
	$themeMenuBtn->pack(-side=>'left')  if (defined $themeMenuBtn);
	$commitMenubtn->pack(-side=>'left');
	$helpMenubtn->pack(-side=>'right');

	my $topFrame = $MainWin->Frame;
	my $sqlrbtnFrame = $topFrame->Frame;
	$sqlrbtnFrame->Radiobutton(
			-text   => '',
			-highlightthickness => 0,
			-variable=> \$use,
			-value  => 'file')->pack(-fill => 'y', -expand => 'yes');
	$sqlrbtnFrame->Radiobutton(
			-text   => '',
			-highlightthickness => 0,
			-variable=> \$use,
			-value  => 'line')->pack(-fill => 'y', -expand => 'yes');
	$sqlrbtnFrame->Radiobutton(
			-text   => '',
			-highlightthickness => 0,
			-variable=> \$use,
			-value  => 'sql')->pack(-fill => 'y', -expand => 'yes');

	$sqlrbtnFrame->pack(-side => 'left',
			-fill	=> 'y',
			-expand	=> 'no');
	my $toprFrame = $topFrame->Frame;
	my $fileFrame = $toprFrame->Frame;
	$fileButton = $fileFrame->Button(
			-text => 'File:',
			-command => [\&getfile]);
	$fileButton->pack(
			-side	=> 'left',
			-expand	=> 'no');
	$fileText = $fileFrame->Entry(
			-relief => 'sunken',
			-width  => 30);
	$fileText->bind('<FocusIn>' => [\&textfocusin]);
	$fileText->pack(
			-side   => 'left',
			-expand => 'yes',
			-fill   => 'x');
	my $delimLabel = $fileFrame->Label(-text=>'  Delimiters:  Field:');
	$delimLabel->pack(-expand => 'no', -side => 'left', -padx => '1m');
	$delimText = $fileFrame->Entry(
			-relief => 'sunken',
			-width  => 6);
	$delimText->bind('<FocusIn>' => [\&textfocusin]);
	$delimText->pack(
			-side   => 'left',
			-expand => 'no',
			-fill   => 'x');
	my $rdelimLabel = $fileFrame->Label(-text=>' Rec:');
	$rdelimLabel->pack(-expand => 'no', -side => 'left', -padx => '1m');
	$rdelimText = $fileFrame->Entry(
			-relief => 'sunken',
			-width  => 6);
	$rdelimText->bind('<FocusIn>' => [\&textfocusin]);
	$rdelimText->pack(
			-side   => 'left',
			-expand => 'no',
			-fill   => 'x');
	my $adelimLabel = $fileFrame->Label(-text=>' Args:');
	$adelimLabel->pack(-expand => 'no', -side => 'left', -padx => '1m');
	$adelimText = $fileFrame->Entry(
			-relief => 'sunken',
			-width  => 6);
	$adelimText->bind('<FocusIn>' => [\&textfocusin]);
	$adelimText->pack(
			-side   => 'left',
			-expand => 'no',
			-fill   => 'x');
	$headerCbtn = $fileFrame->Checkbutton(
			-text   => 'Header',
			-variable=> \$headers);
	$headerCbtn->pack(
			-side	=> 'left',
			-padx	=> '4m');
	$fileFrame->pack(-side	=> 'top',
			-fill	=> 'x',
			-expand	=> 'yes');
	my $wvtextFrame = $toprFrame->Frame;
	my $whereLabel = $wvtextFrame->Label(-text=>'Prompt');
	$whereLabel->pack(-side => 'left');

	my $valusLabel = $wvtextFrame->Label(-text=>' Values:');
	$valusLabel->pack(-side => 'left');
	$valusText = $wvtextFrame->Entry(
			-relief => 'sunken',
			-width  => 72);
	$valusText->bind('<FocusIn>' => [\&textfocusin]);
	$valusText->pack(
			-side   => 'left',
			-expand => 'yes',
			-fill   => 'x');
	$valusLabel->pack(-side => 'left');
	$wvtextFrame->pack(
			-side	=> 'top',
			-expand	=> 'yes',
			-fill	=> 'x');
	my $sqlboxFrame = $toprFrame->Frame;
	my $sqlLabel = $sqlboxFrame->Label(-text=>'SQL: ');
	$sqlLabel->pack(-side => 'left');
	$sqlText = $sqlboxFrame->Text(
			-height => $sqlheight);
	$sqlText->bind('<FocusIn>' => [\&textfocusin]);
	$sqlScrollY = $sqlboxFrame->Scrollbar(
			-relief => 'sunken',
			-orient => 'vertical',
			-command=> [$sqlText => 'yview']);
	$sqlText->configure(-yscrollcommand=>[$sqlScrollY => 'set']);
	$sqlScrollY->pack(
			-side   => 'right',
			-fill   => 'y');
	$sqlText->pack(
			-side   => 'left',
			-expand => 'yes',
			-fill   => 'both');

	$sqlboxFrame->pack(-side => 'top',
			-fill	=> 'both',
			-expand	=> 'x');

	$toprFrame->pack(-side => 'left',
			-expand	=> 'yes',
			-fill	=> 'x');
	$topFrame->pack(-side => 'top',
			-expand	=> 'no',
			-fill	=> 'x');

	$statusFrame = $MainWin->Frame;
	$statusText = $statusFrame->ROText(
			-height => $msgheight);
	$statusText->bind('<FocusIn>' => [\&textfocusin]);
	&BindMouseWheel($statusText)  if ($WheelMouse);
	$statusScrollY = $statusFrame->Scrollbar(
			-relief => 'sunken',
			-orient => 'vertical',
			-command=> [$statusText => 'yview']);
	$statusText->configure(-yscrollcommand=>[$statusScrollY => 'set']);
	$statusScrollY->pack(
			-side   => 'right',
			-fill   => 'y');
	$statusText->pack(
			-side   => 'top',
			-expand => 'yes',
			-fill   => 'both');
##	tie (*STDERR, 'Tk::ROText', $statusText);   #ADDED 20000224 SO I CAN SEE ERRORS!
	$statusText->insert('end', $preStatus);
	$statusText->see('end');

	$statusFrame->pack(
			-side	=> 'bottom',
			-expand	=> 'yes',
			-fill	=> 'both');

	$fmtFrame = $MainWin->Frame;
	$fmtFrame->Label(
			-text	=> 'Format:');
	$fmtButton = $fmtFrame->Button(
			#-padx => '2m',
			-text => 'Format:',
			-command => [\&setdfltfmt]);
	my $fmtTextWidth = 48;
	$fmtTextWidth = 80  unless ($os =~ /x|solaris/);
	$fmtText = $fmtFrame->JBrowseEntry(
			#-height => 6,
			-variable => \$myfmt,
			#-tabcomplete => 1,
			-browsecmd => sub {$fmtTextSel = $myfmt;}, 
			-width  => $fmtTextWidth);
	$fmtText->Subwidget('entry')->bind('<FocusIn>' => [\&textfocusin]);
	$fmtButton->pack(-side => 'left');
	$fmtText->pack(
			-side   => 'left',
			-expand => 'yes',
			-fill   => 'x');
	$fmtFrame->pack(
			-side	=> 'bottom',
			-fill	=> 'x',
			-padx	=> '2m');



	my $btnsFrame = $MainWin->Frame;
	$abortButton = $btnsFrame->Button(
			-text	=> 'BREAK',
			-underline => 0,
			-command=> sub {$abortit = 1;});
	$abortButton->pack(
			-side	=> 'left',
			-expand	=> 1);
	my $selbtnsFrame = $btnsFrame->Frame;
	$selectButton = $selbtnsFrame->Button(
			-text	=> 'SELECT',
			-underline => 0,
				#-command=> [\&doselect]);
			-command=> sub {$doexcel = 0; $doxml = 0; &doselect;});
	$selectButton->pack(
			-side	=> 'left',
			-expand	=> 1);
	$distinctButton = $selbtnsFrame->Checkbutton(
			-text	=> 'Distinct',
				#-highlightthickness => 0,
			-variable => \$distinct);
	$distinctButton->pack(
			-side	=> 'left');
	$selbtnsFrame->pack(
			-side	=> 'left',
			-expand	=> 1);
	$commitButton = $btnsFrame->Button(
			-text	=> 'COMMIT!',
			-underline => 0,
			-command=> [\&docommit]);
	$commitButton->pack(
			-side	=> 'left',
			-expand	=> 1);
	$insertButton = $btnsFrame->Button(
			-text	=> 'INSERT',
			-underline => 0,
			-command=> [\&doinsert]);
	$insertButton->pack(
			-side	=> 'left',
			-expand	=> 1);
	$updateButton = $btnsFrame->Button(
			-text	=> 'UPDATE',
			-underline => 0,
			-command=> [\&doupdate]);
	$updateButton->pack(
			-side	=> 'left',
			-expand	=> 1);
	$deleteButton = $btnsFrame->Button(
			-text	=> 'DELETE',
			-underline => 0,
			-command=> [\&dodelete]);
	$deleteButton->pack(
			-side	=> 'left',
			-expand	=> 1);
	$describeButton = $btnsFrame->Button(
			-text	=> 'DESCRIBE',
			-underline => 3,
			-command=> [\&dodescribe]);
	$describeButton->pack(
			-side	=> 'left',
			-expand	=> 1);
	$btnsFrame->pack(
			-side	=> 'bottom',
			-fill	=> 'x');

	my $selectFrame = $MainWin->Frame;
	my $tableFrame = $selectFrame->Frame;
	$tableHead = $tableFrame->Label(
			-text   => 'Table',
			-relief => 'sunken');
	$tableTail = $tableFrame->Label(
			-text   => '',
			-relief => 'flat');
	$tableList = $tableFrame->Scrolled('Listbox',
			-scrollbars => 'se', 
			-width	 => 16,
			-height => $listheight,
			-relief => 'sunken',
			-exportselection => 0,
			-selectmode => 'browse');
	&BindMouseWheel($tableList)  if ($WheelMouse);

	$tableHead->pack(-side => 'top',
			-fill   => 'x',
			-expand => 'yes');
	$tableTail->pack(-side => 'bottom',
			-fill   => 'x',
			-expand => 'yes');
	$tableList->pack(-side => 'right',
			-fill   => 'both',
			-expand => 'yes');

	my $fieldFrame = $selectFrame->Frame;
	$fieldHead = $fieldFrame->Label(
			-text   => 'Field',
			-relief => 'sunken');
	$fieldTail = $fieldFrame->Label(
			-text   => '',
			-relief => 'flat');
	$fieldList = $fieldFrame->Scrolled('Listbox',
			-scrollbars => 'se', 
			-width	 => 16,
			-height => $listheight,
			-relief => 'sunken',
			-selectmode => 'browse');
                #$fieldScrollY = $fieldFrame->Scrollbar(
                #        -relief => 'sunken',
                #        -orient => 'vertical',
                #        -command=> [$fieldList => 'yview']);
                #$fieldList->configure(-yscrollcommand=>[$fieldScrollY => 'set']);
	&BindMouseWheel($fieldList)  if ($WheelMouse);


	$fieldHead->pack(-side => 'top',
			-fill   => 'x',
			-expand => 'yes');
	$fieldTail->pack(-side => 'bottom',
			-fill   => 'x',
			-expand => 'yes');
                #$fieldScrollY->pack(
                #        -side   => 'right',
                #        -fill   => 'y');
	$fieldList->pack(-side => 'right',
			-fill   => 'both',
			-expand => 'yes');

	my $whereFrame = $selectFrame->Frame;
	$whereHead = $whereFrame->Label(
			-text   => 'where',
			-relief => 'sunken');
	$whereList = $whereFrame->Scrolled('Listbox',
			-scrollbars => 'se', 
			-width	 => 16,
			-height => $listheight,
			-relief => 'sunken',
			-selectmode => 'browse');
	$whereRbtn = $whereFrame->Radiobutton(
			-text   => 'Select',
			-highlightthickness => 0,
			-variable=> \$orderSel,
			-value	=> 'where');
	&BindMouseWheel($whereList)  if ($WheelMouse);

	$whereHead->pack(-side => 'top',
			-fill   => 'x',
			-expand => 'yes');
	$whereRbtn->pack(
			-side	=> 'bottom',
			-fill	=> 'x',
			-expand	=> 'yes');
	$whereList->pack(-side => 'right',
			-fill   => 'both',
			-expand => 'yes');

	my $orderFrame = $selectFrame->Frame;
	$orderHead = $orderFrame->Label(
			-text   => 'Order',
			-relief => 'sunken');
	$orderList = $orderFrame->Scrolled('Listbox',
			-scrollbars => 'se', 
			-width	 => 16,
			-height => $listheight,
			-relief => 'sunken',
			-selectmode => 'browse');
	&BindMouseWheel($orderList)  if ($WheelMouse);
	$orderRbtn = $orderFrame->Radiobutton(
			-text   => 'Select',
			-highlightthickness => 0,
			-variable=> \$orderSel,
			-value	=> 'order');

	$orderHead->pack(-side => 'top',
			-fill   => 'x',
			-expand => 'yes');
	$orderRbtn->pack(
			-side	=> 'bottom',
			-fill	=> 'x',
			-expand	=> 'yes');
	$orderList->pack(-side => 'right',
			-fill   => 'both',
			-expand => 'yes');

	my $ordbyFrame = $selectFrame->Frame;
	$ordbyHead = $ordbyFrame->Label(
			-text   => 'Order By',
			-relief => 'sunken');
	$ordbyList = $ordbyFrame->Scrolled('Listbox',
			-scrollbars => 'se', 
			-width	 => 16,
			-height => $listheight,
			-relief => 'sunken',
			-selectmode => 'browse');
	&BindMouseWheel($ordbyList)  if ($WheelMouse);
	$ordbyHead->pack(-side => 'top',
			-fill   => 'x',
			-expand => 'yes');
	my $ordbybtnFrame = $ordbyFrame->Frame;
	$ordbyRbtn = $ordbybtnFrame->Radiobutton(
			-text   => 'Select',
			-highlightthickness => 0,
			-variable=> \$orderSel,
			-value  => 'ordby');
	$ordbyCbtn = $ordbybtnFrame->Checkbutton(
			-text   => 'Descend',
			-highlightthickness => 0,
			-variable=> \$descorder);
	$ordbyRbtn->pack(
			-side	=> 'left',
			-fill	=> 'x',
			-expand	=> 'yes');
	$ordbyCbtn->pack(
			-side	=> 'left',
			-fill	=> 'x',
			-expand	=> 'yes');
	$ordbybtnFrame->pack(
			-side => 'bottom',
			-fill => 'x',
			-expand => 'yes');

	$ordbyList->pack(-side => 'right',
			-fill   => 'both',
			-expand => 'yes');

	$tableFrame->pack(
			-side   => 'left',
			-fill	=> 'both',
			-expand	=> 'yes');

	$fieldFrame->pack(
			-side   => 'left',
			-fill	=> 'both',
			-expand	=> 'yes');

	$orderFrame->pack(
			-side   => 'left',
			-fill	=> 'both',
			-expand	=> 'yes');

	$whereFrame->pack(
			-side   => 'left',
			-fill	=> 'both',
			-expand	=> 'yes');

	$ordbyFrame->pack(
			-side   => 'left',
			-fill	=> 'both',
			-expand	=> 'yes');

	$selectFrame->pack(
			-side   => 'left',
			-expand	=> 'yes',
			-fill	=> 'x');

	$DIALOG1 = $MainWin->JDialog(
			-title          => 'Attention',
			-text           => '',
			-bitmap         => 'error',
			-default_button => $Ok,
			-escape_button  => $Ok,
			-buttons        => [$OK],
	);
	$DIALOG2 = $MainWin->JDialog(
			-title          => 'Are you Sure?',
			-text           => '',
			-bitmap         => 'info',
			-default_button => $Cancel,
			-escape_button  => $Cancel,
			-buttons        => [$OK, $Cancel],
	);
	$OkAll = 'Ok~All';
	$DIALOG3 = $MainWin->JDialog(
			-title          => 'Attention!',
			-text           => 'Everything look ok to commit?',
			-bitmap         => 'questhead',
			-default_button => $Cancel,
			-escape_button  => $Cancel,
			-buttons        => [$OK, $OkAll, $Cancel],
	);

	$fieldList->bind('<ButtonRelease-1>' => [\&fieldClickFn]);
	$fieldList->bind('<Double-ButtonRelease-1>' => [\&fieldDclickFn]);
	$fieldList->bind('<Return>'        => [\&fieldClickFn,1]);
	$whereList->bind('<ButtonRelease-1>' => [\&whereClickFn]);
	$whereList->bind('<Return>'        => [\&whereClickFn,1]);
	$orderList->bind('<ButtonRelease-1>' => [\&orderClickFn]);
	$orderList->bind('<Return>'        => [\&orderClickFn,1]);
	$tableList->bind('<ButtonPress>' => [\&tableClickFnP]);
	$tableList->bind('<ButtonRelease-1>' => [\&tableClickFn]);
	$tableList->bind('<Double-ButtonRelease-1>' => [\&tableDclickFn]);
	$tableList->bind('<Return>'        => [\&tableClickFn,1]);
	$ordbyList->bind('<Return>'        => [\&ordbyClickFn,1]);
	$ordbyList->bind('<ButtonRelease-1>' => [\&ordbyClickFn]);
#	$MainWin->bind('<Alt-c>' => [$describeButton => "Invoke"]);
#	$MainWin->bind('<Alt-d>' => [$deleteButton => "Invoke"]);
#	$MainWin->bind('<Alt-i>' => [$insertButton => "Invoke"]);
#	$MainWin->bind('<Alt-s>' => [$selectButton => "Invoke"]);
#	$MainWin->bind('<Alt-u>' => [$updateButton => "Invoke"]);
	if ($os =~ /Win/i)
	{
		$tableList->bind('<Enter>', sub { 
			$MainWin->bind('<Alt-MouseWheel>', [ sub { $tableList->xview('scroll',-($_[1]/120)*1,'units') }, Tk::Ev("D")]);
			$MainWin->bind('<MouseWheel>', [ sub { $tableList->yview('scroll',-($_[1]/120)*1,'units') }, Tk::Ev("D")]);
		});
		$tableList->bind('<Leave>', sub { 
			$MainWin->bind('<Alt-MouseWheel>', sub { }) ;
			$MainWin->bind('<MouseWheel>', sub { }) 
		});
		$fieldList->bind('<Enter>', sub { 
			$MainWin->bind('<Alt-MouseWheel>', [ sub { $fieldList->xview('scroll',-($_[1]/120)*1,'units') }, Tk::Ev("D")]);
			$MainWin->bind('<MouseWheel>', [ sub { $fieldList->yview('scroll',-($_[1]/120)*1,'units') }, Tk::Ev("D")]);
		});
		$fieldList->bind('<Leave>', sub { 
			$MainWin->bind('<Alt-MouseWheel>', sub { }) ;
			$MainWin->bind('<MouseWheel>', sub { }) 
		});
		$whereList->bind('<Enter>', sub { 
			$MainWin->bind('<Alt-MouseWheel>', [ sub { $whereList->xview('scroll',-($_[1]/120)*1,'units') }, Tk::Ev("D")]);
			$MainWin->bind('<MouseWheel>', [ sub { $whereList->yview('scroll',-($_[1]/120)*1,'units') }, Tk::Ev("D")]);
		});
		$whereList->bind('<Leave>', sub { 
			$MainWin->bind('<Alt-MouseWheel>', sub { }) ;
			$MainWin->bind('<MouseWheel>', sub { }) 
		});
		$orderList->bind('<Enter>', sub { 
			$MainWin->bind('<Alt-MouseWheel>', [ sub { $orderList->xview('scroll',-($_[1]/120)*1,'units') }, Tk::Ev("D")]);
			$MainWin->bind('<MouseWheel>', [ sub { $orderList->yview('scroll',-($_[1]/120)*1,'units') }, Tk::Ev("D")]);
		});
		$orderList->bind('<Leave>', sub { 
			$MainWin->bind('<Alt-MouseWheel>', sub { }) ;
			$MainWin->bind('<MouseWheel>', sub { }) 
		});
		$ordbyList->bind('<Enter>', sub { 
			$MainWin->bind('<Alt-MouseWheel>', [ sub { $ordbyList->xview('scroll',-($_[1]/120)*1,'units') }, Tk::Ev("D")]);
			$MainWin->bind('<MouseWheel>', [ sub { $ordbyList->yview('scroll',-($_[1]/120)*1,'units') }, Tk::Ev("D")]);
		});
		$ordbyList->bind('<Leave>', sub { 
			$MainWin->bind('<Alt-MouseWheel>', sub { }) ;
			$MainWin->bind('<MouseWheel>', sub { }) 
		});
	}

	#NEXT 11 LINES ADDED 20030920 TO SUPPORT A "READONLY" MODE!

	$readonly = $r || 0;
	unless (!$readonly && (-e "$ENV{HOME}/.sqlrw" || -e "${pgmhome}/.sqlrw"))
	{
		$deleteButton->configure(-state => 'disabled');
		$insertButton->configure(-state => 'disabled');
		$updateButton->configure(-state => 'disabled');
		$commitButton->configure(-state => 'disabled');
		$commitMenubtn->configure(-state => 'disabled');
		$fileMenubtn->entryconfigure('Alter table...', -state => 'disabled');
		$readonly = 1;
	}
	$delimText->insert('end',',');
	$adelimText->insert('end',';');
	$rdelimText->insert('end','\n');
	$commitButton->configure(-state => 'disabled')  unless ($nocommit);

	&loadtable;
	&loadoldfmts;

	$commitButton->configure(-text => 'Autocommit', -state => 'disabled')  if ($dB->{AutoCommit});
	MainLoop;
}
#-----------------------------------------------------------------------



sub dologin
{
	#$dbname = $sysidText->get;
	@dbname = split(/:/,$dbname);
	$dbname = 'T:' . $dbname  if ($#dbname == 1);
	#$dbuser = $dbnameText->get;
	$dbpswd = $pswdText->get;

	&dbconnect();
	my @mycmds;
	if ($#{$precmds{$dbuser}} >= 0)
	{
		@mycmds = @{$precmds{$dbuser}};
	}
	elsif ($#{$precmds{$dbname}} >= 0)
	{
		@mycmds = @{$precmds{$dbname}};
	}
	elsif ($#{$precmds{$dbtype}} >= 0)
	{
		@mycmds = @{$precmds{$dbtype}};
	}
	my $res;
	$preStatus = '';

	$didlogin = 0;
	#$didlogin = 1  if ($$dbi_err == 0);
	if ($dB && !$DBI::err)
	{
		foreach my $i (@mycmds)
		{
			$res = $dB->do($i)
					or $preStatus .= "..INIT ERROR: ".$dB->err.':'.$dB->errstr;
			$res = '<undef>'  unless (defined $res);
			$preStatus .= "..INIT DID: $i; result = $res.\n";
		}
		$didlogin = 1;
	}
	&mainstuff  if ($didlogin);
#	exit (0)  unless ($didlogin); #ADDED CONDITION FOR TK8 TO STOP EXITING!
}

sub dbconnect
{
	my ($mydbname) = $dbname;

	$attb = $attbText->get || $attbs{$dbuser} || $attbs{$dbname} || $attbs{$dbtype};

#if ($dbtype eq 'Sprite' && $os =~ /Win/i)   #SPECIAL KLUDGE JUST FOR ME. #SHOULDN'T NEED ANYMORE (FIXED SPRITE)!
#{
#	unless ($attb =~ /PrintWarn/)
#	{
#		$attb .= ','  if ($attb);
#		$attb .= 'PrintWarn => 0';
#	}
#}
	
	{
		$oplist = ['=','!=','like','not like','<','>','<=','>=','is','is not','=^','!^','in'];
		$sprite = 1;
	}
	if ($rhost =~ /\S/)
	{
		if ($rhost =~ s/^mysql\://)
		{
			$connectstr = "dbi:mysql:database=$mydbname;host=$rhost";
			print "-MYSQL REMOTE- connectstr=$connectstr= user=$dbuser= pswd=****= sid=$ENV{ORACLE_SID}= TT=$ENV{TWO_TASK}=\n";
		}
		else
		{
			$rhostname = $rhost;
			$rhostname = $1  if ($rhostname =~ /(.*)\:/);
			$rhostname .= ':';
			$rhost =~ s/:/;port=/;
			########$mydbname = ''  if ($dbtype eq 'Oracle');
			$connectstr = "dbi:Proxy:hostname=$rhost;dsn=DBI:$dbtype:$mydbname";
			print "-PROXY connectstr=$connectstr= user=$dbuser= pswd=****= sid=$ENV{ORACLE_SID}= TT=$ENV{TWO_TASK}=\n";
			print "-connect($connectstr,$dbuser,****)\n";
		}
		#$dB=DBI->connect($connectstr,$dbuser,$dbpswd) 
		$_ = '';
		eval "\$dB=DBI->connect('$connectstr','$dbuser','$dbpswd',{$attb})"; 
		&show_err("-no login: ".($_ ? $_ : ("err=".DBI->err.':'.DBI->errstr)))
				unless ($dB);
#				|| die \"-no login: err=\".DBI->err.':'.DBI->errstr;";
#		&show_err("-no login: err=$_")  if ($_ && !$dB);
	}
	else
	{
		if ($dbtype eq 'Oracle')
		{
			$ENV{ORACLE_HOME} ||= '/home1/oracle/app/oracle/product/7.3.2';
			$mydbname = '';
			if ($dbname =~ s/^sid=(\w+)$/$1/i)
			{
				$ENV{ORACLE_SID} = $dbname;
				$ENV{TWO_TASK} = '';
			}
			elsif ($dbname =~ s/^tt=(\w+)$/$1/i)
			{
				$ENV{ORACLE_SID} = '';
				$ENV{TWO_TASK} = $dbname;
			}
			elsif ($dbname =~ s/^db=(\w+)$/$1/i)
			{                                                                                       $ENV{ORACLE_SID} = '';
				$ENV{TWO_TASK} = '';
				$mydbname = $1;
			}
			else
			{
				$ENV{ORACLE_SID} = $dbname;
				$ENV{TWO_TASK} = $dbname;
			}
		}
#		elsif ($dbtype eq 'Pg')
#		{
#			$dbname = 'dbname='.$dbname  unless ($dbname =~ /\=/);
#		}
		$connectstr = "dbi:$dbtype:$mydbname";
		$dB->disconnect  if ($dB && $dB ne '1');
		$dB = undef;
		$_ = '';
		print "-connectstr=$connectstr= user=$dbuser= pswd=****= attb={$attb}= sid=$ENV{ORACLE_SID}= TT=$ENV{TWO_TASK}=\n";
		eval "\$dB=DBI->connect('$connectstr','$dbuser','$dbpswd',{$attb})"; 
		&show_err("-no login: ".($_ ? $_ : ("err=".DBI->err.':'.DBI->errstr)))
				unless ($dB);
#		&show_err("-no login: err=$_")  if ($_ && !$dB);  #REQUIRED SINCE FOR..
		#SOME REASON DBI'S ERROR HANDLING DOESN'T PLAY NICE W/SPRITE?!?
	}
	if ($dB)
	{
		#if ($dbtype eq 'mysql' || $rhost =~ /\S/)  #CHGD TO NEXT 20020606!
		if ($dbtype eq 'mysql' || ($rhost =~ /\S/ && $DBI::VERSION < 1.21))
		{
			eval "\$dB->{AutoCommit} = 1";
			$autocommit = 1;
			warn '-MySQL and DBD::Proxy do not support transactions, everything will be committed imediatly!';
		}
		elsif ($attb =~ /AutoCommit\s*\=\>\s*1/)
		{
			eval "\$dB->{AutoCommit} = 1";
		}
		else
		{
			eval "\$dB->{AutoCommit} = 0";
		}
		$dB->do('set TEXTSIZE 65535')  if ($dbtype eq 'Sybase');  #ADDED 20030131 TO FIX "OUT OF MEMORY" ERRORS ON SELECTS FROM SQL-SERVER TABLES.
		$dB->{LongTruncOk} = 1  if ($dbtype eq 'ODBC');      #ODBC.
		$nocommit = 1;
		print "..Logging into \"$dbname\", please stand by...\n";
		$noplaceholders = ($dbtype eq 'Sybase');  #SYBASE DOES NOT UTILIZE PLACHOLDERS VERY WELL & FREETDS/M$-SQLSERVER DONT DO THEM AT ALL :(
		$noplaceholders = $1  if ($attb =~ /\bnoplaceholders\s*\=\>\s*(\d)/);
	}
#	else
#	{
#		eval "print \"Could not connect to database: \".DBI::err.':'.DBI::errstr.\"\\n\"";
#		print "Could not connect to database: $_\n"  if ($_ && !$dB);
#	}
}

sub loadtable
{
	&initsec;

	@tables_found = $dB->tables();
	my ($tablecsr);
	if ($#tables_found < 0)
	{
		if ($dbtype eq 'Oracle' || $dbtype eq 'Sprite')
		{
			#$tablecsr = $dB->prepare("select TABLE_NAME from USER_TABLES")
			$tablecsr = $dB->prepare("select TABLE_NAME from all_tables")
					|| warn "table-prepare: ".$dB->err.':'.$dB->errstr;
		}
		elsif ($dbtype eq 'mysql' || $dbtype eq 'LDAP')
		{
			$tablecsr = $dB->prepare("show TABLES")
					|| warn "table-prepare: ".$dB->err.':'.$dB->errstr;
		}
		if ($tablecsr)
		{
			$tablecsr->execute 
			|| warn "table-xeq: $$dbi_err: ".$dB->err.':'.$dB->errstr;
		}
	}

$sUperman = 1; #  if ($ENV{USER} eq 'xjturner');
	unless ($sUperman)
	{
		$sUperman = &chkacc('--',$me);		
		$sUperman = &chkacc($dbtype,$me)  unless ($sUperman);  #ADDED 20000531.
		$sUperman = &chkacc($dbname,$me)  unless ($sUperman);
		$sUperman = &chkacc("$dbname:$dbuser",$me)  unless ($sUperman);
		$sUperman = &chkacc("$dbtype:$dbname:$dbuser",$me)  unless ($sUperman);  #ADDED 20000531.
		#$sUperman = 1  if ($dbtype eq 'Sprite');
	}
	my $tablefid = $ENV{HOME} . '/.sqltable.' . &tolower(substr($dbtype,0,3));
	my $skipfid = $ENV{HOME} . '/.sqlskip.' . &tolower(substr($dbtype,0,3));
	if ($skipfid && open(IN, "<$skipfid"))
	{
		$skipfid = <IN>;
		$skipfid =~ s/\s+$//;
		close IN;
		$skipfid = '=~ ' . $skipfid  unless ($skipfid =~ /^\s*[\=\!]/);
	}
	else
	{
		$skipfid = undef;
	}

	unless (-e $tablefid)
	{
		$tablefid = $pgmhome . 'sqltables.' . &tolower(substr($dbtype,0,3));
	}
	if ($tablecsr)
	{
		while (($table_name) = $tablecsr->fetchrow)
		{
			$_ = "\$table_name $skipfid";
			unless ($skipfid && eval $_)
			{
				push(@tables_found,$table_name)  if ($sUperman || &chkacc("$dbname:$dbuser:$table_name",$me));
			}
		}
		$tablecsr->finish;
	}
	else
	{
		my (@all_tables) = @tables_found;
		@tables_found = ();
		for ($i=0;$i<=$#all_tables;$i++)
		{
			$_ = "\$all_tables[\$i] $skipfid";
			unless ($skipfid && eval $_)
			{
				push(@tables_found,$all_tables[$i])  if ($sUperman || &chkacc("$dbname:$dbuser:$all_tables[$i]",$me));
			}
		}
	}
	my ($slash) = $/;    #NEXT 2 ADDED 20011001!
	$/ = "\n";
	if (open(IN,"<$tablefid"))
	{
		while (<IN>)
		{
			chomp;
			push(@tables_found,$_)  if (/\S/ && ($sUperman || &chkacc("$dbname:$dbuser:$_",$me)));
		}
		close (IN);
	}
	$/ = $slash;    #ADDED 20011001!
	if ($dbtype eq 'ODBC')
	{
		for ($i=0;$i<=$#tables_found;$i++)   #ODBC-SPECIFIC.
		{
			$tables_found[$i] =~ s/^$dbuser\.//i;
			#$tables_found[$i] =~ s/\".*?\"\.//i;  #CHGD. TO NEXT 20040819.
			$tables_found[$i] = $1  if ($tables_found[$i] =~ /\"([^\"]+)\"\s*$/);
			$tables_found[$i] =~ tr/a-z/A-Z/;
		}
	}
	else    #ADDED 20000821!
	{  
		for ($i=0;$i<=$#tables_found;$i++)   #ODBC-SPECIFIC.
		{
			$tables_found[$i] =~ s/^$dbname\.//i;
			$tables_found[$i] =~ s/^$dbuser\.//i;
		}        
	}                
	$fieldList->delete('0.0','end');
	$orderList->delete('0.0','end');
	$whereList->delete('0.0','end');
	$ordbyList->delete('0.0','end');
	$tableList->delete('0.0','end');
	foreach (sort @tables_found)
	{
		$tableList->insert('end',$_);
	}
	$newwhere = 1;
}

sub loadoldfmts
{
	@fmtTextList = ();
	my $fmtfid = $ENV{HOME} . '/.' . substr($dbuser,0,7) 
			. '.' . &tolower(substr($dbtype,0,3));
	#unless (-e $fmtfid)
	#{
	#	$fmtfid = $ENV{HOME} . '/.sqlplfm.dat';
	#}
	#if (open(IN,"<.sqlplfm.dat"))
	if (open(IN, "<$fmtfid"))
	{
		while (<IN>)
		{
			chomp;
			$fmtText->insert('end',$_);
			push (@fmtTextList,$_);
		}
		close IN;
	}
}

sub loadBrowseChoices
{
	my $tablefid = '.sqlplcfg.txt';
	unless (-e $tablefid)
	{
		$tablefid = $ENV{HOME} . '/.sqlplcfg.txt';
	}
	unless (-e $tablefid)
	{
		$tablefid = $pgmhome . 'sqlplcfg.txt';
	}
	#if (open(IN,"<${pgmhome}sqlplcfg.txt"))
	my ($b, $d, $r);
	@usedbs = ();
	if (open(IN,"<$tablefid"))
	{
		my ($browsefield,$browseval,$arg1,$arg2,$arg3,$arg4);
		while (<IN>)
		{
			chomp;
			($browsefield,$browseval) = split(/=/, $_, 2);
			if ($browsefield eq 'dbname')
			{
				#$sysidText->insert('end',$browseval);
				($arg1, $arg2, $arg3, $arg4) = split(/\:/, $browseval);
				push (@dbnames, $arg1);
				$dbthemes{$arg1} = $arg4||'';
				$attbs{$arg1} = $1  if ($arg2 =~ s/\{([^\}]+)\}//);
				@{$precmds{$arg1}} = split(/\;/, $arg2)  if ($arg2);
				$dbname = $arg1  unless ($b);
				$dbthemes{$arg1} = $arg4  if ($arg4);
				$dbtypes{$arg1} = $arg3  if ($arg3);
				$b = 1;
			}
			elsif ($browsefield eq 'dbuser')
			{
				#$dbnameText->insert('end',$browseval);
				($arg1, $arg2, $arg3, $arg4) = split(/\:/, $browseval);
				push (@dbusers, $arg1);
				$attbs{$arg1} = $1  if ($arg2 =~ s/\{([^\}]+)\}//);
				@{$precmds{$arg1}} = split(/\;/, $arg2)  if ($arg2);
				$dbuser = $arg1  unless ($d);
				$dbthemes{$arg1} = $arg4  if ($arg4);
				$dbtypes{$arg1} = $arg3  if ($arg3);
				$d = 1;
			}
			elsif ($browsefield eq 'dbtype')
			{
				($arg1, $arg2, $arg3) = split(/\:/, $browseval);
				$attbs{$arg1} = $1  if ($arg2 =~ s/\{([^\}]+)\}//);
				@{$precmds{$arg1}} = split(/\;/, $arg2)  if ($arg2);
				$dbtype = $arg1;
				$dbthemes{$arg1} = $arg3  if ($arg3);
			}
			elsif ($browsefield eq 'host')
			{
				#$rhostEntry->insert('end',$browseval);
				push (@rhosts, $browseval);
				$rhost = $browseval  unless ($r);
				$r = 1;
			}
			elsif ($browsefield eq 'use')
			{
				push (@usedbs, $browseval);
			}
			else
			{
				${$browsefield} = $browseval  unless (${$browsefield} =~ /\S/);
			}
		}
		close IN;
	}
}

sub tableClickFnP
{
	my $mychoice = $tableList->curselection;
	$tableList->selection('set',$mychoice);
}

sub tableClickFn
{
	$mytable = $tableList->get('active');
	$tableHead->configure(-text => "Table=$mytable");

#	$statusText->delete('0.0','end'); #DECIDED NOT TO CLEAR STATUS MSGS!
	$mytable =~ s/.*\.//;
	if ($dbtype eq 'mysql')
	{
		$fieldcsr = $dB->prepare("LISTFIELDS $mytable", {'mysql_use_result' => 1}) 
				|| &show_err("fields: prepare: ".$dB->err.':'.$dB->errstr);
	}
	elsif ($dbtype eq 'Sybase')  #THIS MAY WORK W/OTHER dB'S, BUT I DON'T KNOW, PLEASE SOMEONE ENLIGHTEN ME!
	{
		$fieldcsr = $dB->prepare("select top 1 * from $mytable")
				|| &show_err("fields: prepare: ".$dB->err.':'.$dB->errstr);
	}
	else
	{
		$fieldcsr = $dB->prepare("select * from $mytable", {ldap_sizelimit => 1, sprite_sizelimit => 1}) 
				|| &show_err("fields: prepare: ".$dB->err.':'.$dB->errstr);
	}
	$fieldcsr->execute  
	|| &show_err("fields: xeq: ".$dB->err.':'.$dB->errstr);
	#(@titles) = &ora_titles($fieldcsr,0);
	@titles = @{$fieldcsr->{NAME}};
	$fieldList->delete('0.0','end');
	$orderList->delete('0.0','end');
	$whereList->delete('0.0','end');
	$ordbyList->delete('0.0','end');
        #$sqlText->delete('0.0','end');
	$valusText->delete('0.0','end');
	$orderSel = 'order';

	for ($i=0;$i<=$#titles;$i++)
	{
		$fieldList->insert('end',$titles[$i]);
	}
	$fieldList->insert('end','<---filler--->');
    #&ora_close($fieldcsr);
	$fieldcsr->finish;
	$use = 'line';
	$newwhere = 1;
}

sub tableDclickFn
{
	my ($myfield) = $tableList->get('active');
	$sqlText->insert('insert',$myfield);
	$sqlText->focus;
	$use = 'sql';
}

sub fieldClickFn
{
	my ($myfield) = $fieldList->get('active');
	$cmd = "\$".$orderSel."List->insert('end',$myfield);";
	eval $cmd;
	$fieldList->focus();
}

sub fieldDclickFn
{
	my ($myfield) = $fieldList->get('active');
	$sqlText->markSet('mymark','insert');
	$sqlText->insert('insert',$myfield);
	$sqlText->see('mymark');
	$mychoice = $fieldList->index('end');
	my $myfield2 = $fieldList->get($mychoice);
	### $fieldList->delete('end')  if ($myfield eq $myfield2);
	$cmd = "\$".$orderSel."List->delete('end')";
	eval $cmd;
	$sqlText->focus;
	$use = 'line';
}

sub whereClickFn
{
	$whereList->delete('active');
#	$newwhere = 1;   #COMMENTED 20030812 (CONVENIENCE) TO ALLOW REMOVAL OF CRITERIA W/O RESETTING VALUES.
	$whereList->focus();
}

sub orderClickFn
{
	$orderList->delete('active');
	$orderList->focus();
}

sub ordbyClickFn
{
	$ordbyList->delete('active');
	$ordbyList->focus();
}

sub getfile
{
	my $mytitle = "Select delimited flatfile:";
	my ($create) = 1;     #THIS MUST BE 1.
	my ($fileDialog) = $MainWin->JFileDialog(
			-Title=> $mytitle,
			-Path => $startfpath || $ENV{PWD},
			-History => 12,
			-HistFile => "$ENV{HOME}.sqlhist",
			-Create=>$create);

	$myfile = $fileDialog->Show();
	#$startfpath = $fileDialog->{Configure}{-Path};
	$startfpath = $fileDialog->getLastPath();
	if ($myfile =~ /\S/)
	{
		$fileText->delete('0.0','end');
		$fileText->insert('end',$myfile);
	}
	$use = 'file';
}

sub doSprite
{
	$dosprite = 1;
	$doexcel = 0;
	$doxml = 0;
	&doselect;
	$dosprite = 0;
}

sub doExcel
{
	return 0  if ($noexcel);
	$dosprite = 0;
	$doexcel = 1;
	$doxml = 0;
	&doselect;
	$doexcel = 0;
}

sub doXML
{
	return 0  if ($noxml);
	$dosprite = 0;
	$doexcel = 0;
	$doxml = 1;
	%xmleschash = (
		'<' => '&lt;',
		'>' => '&gt;',
		'"' => '&quot;',
		'--' => '&#45;&#45;',
	#		"\0" => '&#0;'
	);	
	&doselect;
	$doxml = 0;
}

sub doselect
{
	#my ($myline, $mymyfmt, $myfmtstmt, $myfmtstmt2, $myfmtstmtH, $myfmtstmtH2, $mycnt, $mysel, $usrres, $myselect, $myfile, $mydelims);
	my ($myline, $mycnt, $mysel, $usrres, $myselect, $myfile, $mydelims);
	my (@titles, @types, @lens, %typesH, %lensH, @mytypes, @mylens, $selcsr);
	my ($fullheaderlist);

	local ($mymyfmt) = $myfmt;
	@fieldvals = ();
	my ($bindcnt, @wherebits);
	$mypaglen = 0;
	my ($reccount) = 0;
#        $statusText->delete('0.0','end');
	$myfile = $fileText->get;
	if ($doexcel && $myfile !~ /\S/)
	{
		$DIALOG1->configure(
				-text => "Must specify an output file!");
		$usrres = $DIALOG1->Show();
		return;
	}
	($mysdelim,$myjdelim) = &getdelims(0);
	my ($myasdelim, $myajdelim) = &getdelims(2);
	my ($myrsdelim,$myrjdelim) = &getdelims(1);  #FETCH RECORD DELIMITERS.
	my ($slash) = $/;
	$/ = $myrjdelim;
	$errorsfound = 0;
	if ($use ne 'file')
	{
		$usrres = 'No';
	}
	elsif (-e $myfile)
	{
		$DIALOG2->configure(
				-text => "File \"$myfile\" exists, overwrite?");
		$usrres = $DIALOG2->Show();
	}
	else
	{
		$usrres = $OK;
	}
	$bindcnt = 0;
	if ($use eq 'sql')   #NOTE: SECURITY HOLE: CURRENTLY ONLY CHECKS 1ST TABLE!!!
	{
		$myselect = $sqlText->get('0.0','end');
		$myselect =~ s/;+$//;

		#NEXT 6 LINES ADDED 20030920 TO SUPPORT A "READONLY" MODE!

		if ($readonly && $myselect =~ /^\s*(?:insert|update|drop|delete|truncate)/i)
		{
			&show_err("..MAY NOT PERFORM THIS QUERY IN READONLY MODE!\n");
			$/ = $slash;
			return;
		}
		if ($myselect =~ /^\s*(?:drop|delete|truncate)/i)
		{
			$DIALOG2->configure(
					-text => "ABOUT TO DROP/DELETE/TRUNCATE TABLE!\nAre you SURE?");
			return (0)  if ($DIALOG2->Show() ne $OK);
		}
		$myselect =~ s/\sinto\s+\:\w+(\s+\:\w+)*//;  #ADDED 20011217.
		$myselect =~ /\b(?:table|into|from|update)\b\s*([^\s\,]+)/i;
		$chktable = "\U$1";
		unless ($sUperman || &chkacc("$dbname:$dbuser:$chktable",$me))
		{
			$chktable =~ s/,\s+/,/g;
			@chktables = split(/,/,$chktable);
			foreach (@chktables)
			{
				unless (&chkacc("$dbname:$dbuser:$_",$me))
				{
					&show_err("..NOT AUTHORIZED TO ACCESS TABLE \"$chktable\"\!\n");
					$/ = $slash;
					return;
				}
			}
		}
	}
	else
	{
		$StuffEnterred = 0;
		my (@fieldlist) = $orderList->get('0','end');
		my (@orderlist) = $ordbyList->get('0','end');
		my (@wherelist) = $whereList->get('0','end');

		my $useTop2Limit = '';
		$useTop2Limit = 'top 1 '  if ($dbtype eq 'Sybase');
		if ($selcsr = $dB->prepare('select '.$useTop2Limit." * from $mytable", {ldap_sizelimit => 1, sprite_sizelimit => 1}))
		{	
			$selcsr->execute;
			&show_err("sql select: EXEC ERROR: ".$dB->err.':'.$dB->errstr)  if ($dB->err);
			#@lens = @{$selcsr->{PRECISION}};
			@titles = @{$selcsr->{NAME}};
			@types = @{$selcsr->{TYPE}};
			@lens = @{$selcsr->{PRECISION}};
			if ($dbtype eq 'Oracle')
			{
				my @oralens = @{$selcsr->{'ora_lengths'}};   #ORACLE-SPECIFIC.
				for (my $i=0;$i<=$#lens;$i++)
				{
					$lens[$i] ||= $oralens[$i];
				}
			}
			elsif ($dbtype eq 'mysql')
			{
				@lens = @{$selcsr->{mysql_length}};
			}
			$selcsr->finish;
			for (my $i=0;$i<=$#titles;$i++)
			{
				$typesH{$titles[$i]} = $types[$i];
				$lensH{$titles[$i]} = $lens[$i];
			}
		}
		$wherestuff = $sqlText->get('0.0','end');
		$wherestuff =~ s/\n//g;
		@ops = ();
		@relops = ();
		$mysel = join(',',@fieldlist);
		$mysel = '*'  if ($#fieldlist < 0);
		$myselect = 'select ';
		$myselect .= 'distinct '  if ($distinct);
		$myselect .= "$mysel from ".$mytable;
		#$myselect .= ' where '.$wherestuff  if ($wherestuff =~ /\S/);
		if ($wherestuff =~ /\S/ && $#wherelist < 0)
		{
			#EMPTY WHERE-LIST - TREAT STUFF IN SQL BOX AS A COMPLETE
			#WHERE-CLAUSE.

			$myselect .= ' where ' . $wherestuff;
			$wherestuff = '';
		}
		elsif ($#wherelist >= 0)
		{
			$StuffEnterred = 0;
			if ($wherestuff =~ /\S/)
			{
				#TREAT WHERE-STUFF AS LIST OF VALUES
				#FOR FIELDS LISTED IN ORDER-BY LIST.

				@fieldvals = split($myasdelim,$wherestuff,-1);   #NOTHING TO FIX HERE - IF VALUE HAS QUOTES, INCLUDE THEM.
				$fieldvals[0] = ''  if ($#fieldvals < 0);
				$wherestuff = '';
				for (0..$#wherelist)
				{
					$wherestuff .= $myajdelim  if ($_ > 0);
					$wherestuff .= $wherelist[$_] . '=' . $fieldvals[$_];
				}
				$StuffEnterred = 2;
			}
			else
			{
				&inputscr(1);  #PROMPT FOR WHERE-STUFF.
			}
			unless ($StuffEnterred)
			{
				$/ = $slash;
				return (0);
			}
		}
		if ($wherestuff =~ /\S/)
		{
			$myselect .= ' where ';
			@fieldvals = ();
			@wherebits = split($myasdelim,$wherestuff,-1);
			$wherebits[0] = ''  if ($#wherebits < 0);
			for ($i=0;$i<=$#wherebits;$i++)
			{
				$wherebits[$i] =~ s/\x02/$myajdelim/g;
				($wherevars,$wherevals) = split(/=/,$wherebits[$i],2);
				if ($ops[$i])
				{
					$wherevals =~ s/\\([\%\_])/$1/g;
					if ($ops[$i] eq ' is' || $ops[$i] eq ' is not')
					{
						$myselect .= $wherevars . $ops[$i] . ' NULL';
					}
					elsif ($ops[$i] eq ' in')
					{
						if ($wherevals =~ /^\s*\(.*\)\s*$/)
						{
							$myselect .= $wherevars . $ops[$i] . ' ' . $wherevals;
						}
						else
						{
							$myselect .= $wherevars . $ops[$i] . ' ('.$wherevals.') ';
						}
					}
					else
					{
						#my @isNumeric = DBI::looks_like_number($wherevals);
						if ($StuffEnterred == 2 && $wherevals !~ /^([\'\"]).*\1$/
								&& $wherevals =~ /^[A-Z_]/io)
						{
							$myselect .= $wherevars . $ops[$i] . ' ' . $wherevals;
							$preboundHash{$i} = 1;
						}
						else
						{
							++$bindcnt;
							$myselect .= $wherevars . $ops[$i] . ' ?';
							$wherevals .= '%'  if ($ops[$i] =~ /like/ && $wherevals !~ /[\%\_]/);
							push (@fieldvals,$wherevals);
							push (@mytypes, $typesH{$wherevars});
							push (@mylens, $lensH{$wherevars});
						}
					}
				}
				elsif ($wherevals =~ /[^\\][\%\_]/)
				{
					#my @isNumeric = DBI::looks_like_number($wherevals);
					if ($StuffEnterred == 2 && $wherevals !~ /^([\'\"]).*\1$/
							&& $wherevals =~ /^[A-Z_]/io)
					{
						$myselect .= $wherevars . ' like ' . $wherevals;
						$preboundHash{$i} = 1;
					}
					else
					{
						++$bindcnt;
						$myselect .= $wherevars . ' like ?';
						push (@fieldvals,$wherevals);
						push (@mytypes, $typesH{$wherevars});
						push (@mylens, $lensH{$wherevars});
					}
				}
				else
				{
					$wherevals =~ s/\\([\%\_])/$1/g;
					#my @isNumeric = DBI::looks_like_number($wherevals);
					if (!length($wherevals))
					{
						$myselect .= $wherevars . ' is NULL';
						$preboundHash{$i} = 1;
					}
					elsif ($StuffEnterred == 2 && $wherevals !~ /^([\'\"]).*\1$/
							&& $wherevals =~ /^[A-Z_]/io)
					{
						$myselect .= $wherevars . ' = ' . $wherevals;
						$preboundHash{$i} = 1;
					}
					else
					{
						++$bindcnt;
						$myselect .= $wherevars . ' = ?';
$wherevals =~ s/^([\'\"])(.*)\1$/$2/;
						push (@fieldvals,$wherevals);
						push (@mytypes, $typesH{$wherevars});
						push (@mylens, $lensH{$wherevars});
					}
				}
				$myselect .= $relops[$i]|| (($myajdelim =~ /^\|\|?$/) ? ' or ' : ' and ')  if ($i < $#wherebits);
			}
		}
		if ($#orderlist >= 0)
		{
			$myselect .= ' order by '.join(',',@orderlist);
			$myselect .= ' DESC'  if ($descorder);
		}
	}
	chomp ($myselect);
	##$statusText->insert('end',"..DID QUERY: $myselect.  $reccount records selected.\n");
	$statusText->insert('end',"..DOING QUERY: $myselect.\n");
	$statusText->see('end');
	#$fieldcsr = &ora_open($dB,$myselect)

	my $myPHselect = $myselect;
	$myselect =~ s/([\'\"])([^\1]*?)\1/
			my ($quote) = $1;
			my ($str) = $2;
			$str =~ s|\?|\x02\^2jSpR1tE\x02|g;   #PROTECT ?'S IN QUOTES.
			"$quote$str$quote"
	/egs;
	my $t;
	for (my $i=0;$i<$bindcnt;$i++)
	{
		$t = $fieldvals[$i];
		if (defined $t)   #CONDITION & ELSE ADDED 20050209 2 BETTER HANDLE NULLS.
		{
			$t =~ s/\'/\'\'/gs;
			$t =~ s/\?/\x02\^2jSpR1tE\x02/gs;
#				if ($dbtype eq 'Sybase' && $t =~ /^((?:\'\')?)[\d\.\+\-]+\1$/)  #ADDED 20060427 TO PREVENT ERROR!
			if ($t eq '')
			{
				$myselect =~ s/\?/NULL/;
			}
			elsif ($StuffEnterred == 2 || ($mytypes[$i] >= 2 && $mytypes[$i] <= 8) 
					|| $mytypes[$i] == 1700 || $mytypes[$i] == -5
					|| $mytypes[$i] == -6)
			{
				$t =~ s/^\'\'(.*)\'\'$/\'$1\'/;
				$myselect =~ s/\?/$t/s;
			}
			else
			{
				$myselect =~ s/\?/\'$t\'/s;
			}
		}
		else
		{
			$myselect =~ s/\?/NULL/s;
		}
	}
	$myselect =~ s/\x02\^2jSpR1tE\x02/\?/gs;     #UNPROTECT ?'S IN QUOTES.
	if ($noplaceholders)
	{
		$fieldcsr = $dB->prepare($myselect)
				|| &show_err("sql select: OPEN ERROR: ".$dB->err.':'.$dB->errstr);
	}
	else
	{
		$fieldcsr = $dB->prepare($myPHselect) 
				|| &show_err("sql select: OPEN ERROR: ".$dB->err.':'.$dB->errstr);

		#&ora_bind($fieldcsr, @fieldvals)  if ($bindcnt);
		for my $i (1..$bindcnt)
		{
			$fieldcsr->bind_param($i, $fieldvals[$i-1], {TYPE => $mytypes[$i-1]})
					|| &show_err("sql select: BIND ERROR: ".$dB->err.':'.$dB->errstr);
		}
	}
	$fieldcsr->execute;
	&show_err("sql select: EXEC ERROR: ".$dB->err.':'.$dB->errstr)  if ($dB->err);
	if ($myselect =~ /^\s*(?:create|drop|delete|alter|truncate)/i)
	{
		&loadtable();

		#ADDED 20020620 TO AUTO-GENERATE A "TDF" (TABLE-DEFINITION FILE)
		#WHEN A TABLE IS CREATED OR ALTERED, IF A "DATA-DEFINITION PATH
		#(DDPATH) PARAMETER IS SPECIFIED IN .SQLPLCFG.TXT!
		if ($ddpath)

		{
			if ($myselect =~ /^\s*create\s+table\s+([^\s\(]+)/i)
			{
				$mytable = $1;
				my $primarykeys = '';
				$primarykeys = $1  if ($myselect =~ /primary\s+keys?\s*\(([^\)]+)\)/s);
				&dodescribe(4, $primarykeys);
			}
			elsif ($myselect =~ /^\s*alter\s+table\s+([^\s\(]+)/i)
			{
				$mytable = $1;
				my $primarykeys = '';
				$ddpath .= $osslash  if ($ddpath && $ddpath !~ m#${osslash}$#);
				if (open(IN,"<${ddpath}${mytable}.tdf"))
				{
					while (<IN>)
					{
						chomp;
						if (/primary\s+keys?\s*\(([^\)]+)\)/s)
						{
							$primarykeys = $1;
							last;
						}
					}
					close (IN);
				}
				&dodescribe(4, $primarykeys);
			}
		}
		$statusText->insert('end',".......DID above command.\n")  unless ($dB->err);
		$statusText->see('end');
	}
	else
	{
		$xpopup->destroy  if (Exists($xpopup));
		$xpopup = $MainWin->Toplevel;
		$xpopup->title("Selected records: ($myselect)");

		my $xpopupFrame = $xpopup->Frame;
		$xpopupText = $xpopupFrame->ROText(
				-font	=> $fixedfont,                 #PC-SPECIFIC.
				-relief => 'sunken',
				-setgrid=> 1,
				-wrap	=> 'none',
	                #-height => 25,
				-width  => 80);
		my $w_menu = $xpopup->Frame(-relief => 'raised', -borderwidth => 2);
		$w_menu->pack(-fill => 'x');

		my $fileMenubtn = $w_menu->Menubutton(-text => 'File', -underline => 0);
		$fileMenubtn->command(-label => 'Break', -underline =>0, -command => sub {$abortit = 1;});
		$fileMenubtn->command(-label => 'Save',    -underline =>0, -command => [\&doSave]);
		$fileMenubtn->separator;
		$fileMenubtn->command(-label => 'Close',   -underline =>0, -command => [$xpopup => 'destroy']);
		$fileMenubtn->command(-label => 'eXit',    -underline =>1, -command => \&exitFn);

		my $editMenubtn = $w_menu->Menubutton(-text => 'Edit', -underline => 0);
		$editMenubtn->command(-label => 'Copy',   -underline =>0, -command => [\&doCopy]);
		$editMenubtn->separator;
		$editMenubtn->command(
				-label => 'Find', 
				-underline =>0, 
				-accelerator => 'Alt-s',
				-command => [\&newSearch,$xpopupText,1]);
		$editMenubtn->command(-label => 'Modify search',   -underline =>0, -command => [\&newSearch,$xpopupText,0]);
		$editMenubtn->command(
				-label => 'Again', 
				-underline =>0, 
				-accelerator => 'Alt-a',
				-command => [\&doSearch,$xpopupText,0]);

		$fileMenubtn->pack(-side=>'left');
		$editMenubtn->pack(-side=>'left');
			#$xpopup->bind('<Alt-a>' => [\&doSearch,$xpopupText,0]);
		$xpopupText->bind('<FocusIn>' => [\&textfocusin]);

		my $xpopupScrollY = $xpopupFrame->Scrollbar(
				-relief => 'sunken',
				-orient => 'vertical',
				-command=> [$xpopupText => 'yview']);
		$xpopupText->configure(-yscrollcommand=>[$xpopupScrollY => 'set']);

		$xpopupScrollY->pack(-side=>'right', -fill=>'y');
		$xpopupScrollX = $xpopupFrame->Scrollbar(
				-relief => 'sunken',
				-orient => 'horizontal',
				-command=> [$xpopupText => 'xview']);
		$xpopupText->configure(
				-xscrollcommand=>[$xpopupScrollX => 'set']);
		$xpopupScrollX->pack(
				-side   => 'bottom', -fill=>'x');
		$xpopupText->pack(
				-side	=> 'left',
				-expand	=> 'yes',
				-fill	=> 'both');
		my $recLabel = $xpopup->Label(
				-text   => "$reccount records found",
				-relief => 'ridge');
		my $btnFrame = $xpopup->Frame;
		my $okButton = $btnFrame->Button(
				-text => 'Ok',
				-underline => 0,
		                #-command => [$xpopup => 'destroy']);
				-command => sub {$abortit = 1; $xpopup->destroy;});
		$okButton->pack(-side=>'left', -expand => 1);
		        #$okButton->pack(-side=>'left');
		my $abortButton = $btnFrame->Button(
				-text => 'Break',
				-underline => 0,
				-command => sub {$abortit = 1;});
		$abortButton->pack(-side=>'left', -expand => 1);
		        #$abortButton->pack(-side=>'left' -fill => x);
		my $copyButton = $btnFrame->Button(
				-text => 'Copy',
				-underline => 0,
				-command => sub {&doCopy();});
		$copyButton->pack(
				-side=>'left', 
				-expand => 1);
		$btnFrame->pack(
				-side   => 'bottom',
				-fill   => 'x',
				#-expand => 1,
				-padx   => '2m',
				-pady   => '2m');
		$recLabel->pack(
				-side   => 'bottom');
		$xpopupFrame->pack(
				-side	=> 'bottom',
				-expand	=> 'yes',
				-fill	=> 'both');

		$xpopup->bind('<Return>' => [$okButton => "Invoke"]);
		$okButton->focus;
	#	$xpopup->bind('<Alt-o>' => [$okButton => "Invoke"]);
		$xpopup->bind('<Escape>' => [$okButton => "Invoke"]);


		###$myfmt = $fmtText->get;
		($mysdelim,$myjdelim) = &getdelims(0);
		my $doCSV;
		$doCSV = $1  if ($myjdelim =~ /^\"(\S+)\"$/);  #20060619: HANDLE CSV FILES!
#print "-mytable=$mytable=\n";
		$myjdelim = $doCSV  if ($doCSV);
		if ($doexcel)   #ADDED 20010524!
		{
			$xls = Spreadsheet::WriteExcel->new("$myfile");
			$xlssheet   = $xls->addworksheet($mytable);

			# Create a right-justify format for numeric fields.

			$numericfmt = $xls->addformat();
			$numericfmt->set_align('right');

			$normalfmt = $xls->addformat();
			$normalfmt->set_align('left');
		}
		if ($myfmt =~ /\S/ && !$doxml)
		{
			foreach $i (@fmtTextList)
			{
				goto SAMEFMT  if ($i eq $myfmt);
			}
			$fmtText->insert('0',$myfmt);
			unshift (@fmtTextList, $myfmt);;
#$x = $fmtText->index('end');
#print "-index=$x=\n";
			if ($#fmtTextList >= $fmtmax)
			{
				$fmtText->delete('end','end');
				pop (@fmtTextList);
			}
SAMEFMT:			
			$linecnt = 0;
			open(OUTFILE,">.sqlout.tmp") || warn "Could not create temp. file($!)!";
			binmode OUTFILE;    #20000404
			#@headerlist = ();
			#@headerlist = $orderList->get('0','end');
			#@headerlist = $fieldList->get('0','end')  if ($#headerlist < 0);

			$mymyfmt =~ s/\\\\/\x02/g;   #PROTECT DOUBLE-SLASHES.
			$mymyfmt =~ s/\\%/\x03/g;   #PROTECT ESCAPED PERCENT-SIGNS.
			$mymyfmt =~ s/\\\@/\x04/g;   #PROTECT ESCAPED PERCENT-SIGNS.
			@sumlist = ($mymyfmt =~ /(\@|\%|\#|\&)/g);
#print "--sums=".join(',',@sumlist).'= ';

			my ($showsums) = 0;
			for (my $i=0;$i<=$#sumlist;$i++)
			{
				$sums[$i] = '';
				if ($sumlist[$i] eq '&')
				{
					$sumlist[$i] = 1;
					$showsums = 1;
				}
				else
				{
					$sumlist[$i] = 0;
				}
			}
			$mymyfmt =~ s/\&/\@/g;
			if ($newfmt)
			{
				@fmts = ($mymyfmt =~ /(\s*[\@\&\#\%]\S*)/g);
				$mymyfmt = '';
				for (my $i=0;$i<=$#fmts;$i++)
				{
					$fmts[$i] =~ s/[\@\&\#](\d+)(.)/
					$2 x ($1 + 1)
							/e;
					$fmts[$i] =~ s/[\@\&\#]/\>/;
					if ($fmts[$i] =~ /\%([\+\-]?)(\d+)/)
					{
						$lens[$i] = $2;
						$fmtjust[$i] = ($1 eq '-') ? '<' : '>';
					}
					else
					{
						$lens[$i] = length($fmts[$i]);
						$fmtjust[$i] = ($fmts[$i] =~ /([\^\>])/) ? $1 : '<';
					}
#print "-fmt=$fmts[$i]= len=$lens[$i]= just=$fmtjust[$i]= sep=$seps[$i]=\n";
					#$mymyfmt .= $fmts[$i];
					$fmts[$i] =~ s/ \< / \<\</;   #HACK AROUND BUG IN TEXT::AUTOFORMAT :-(
					$fmts[$i] =~ s/ \> /\>\> /;   #HACK AROUND BUG IN TEXT::AUTOFORMAT :-(
				}
				$mymyfmt = join("\x05", @fmts);
#print "-1- mymyfmt=$mymyfmt=\n";
				$mymyfmt =~ s/\%[\+\-]?(\d+)./
						'<' x ($1 + 1)
						/eg;
#print "-2- mymyfmt=$mymyfmt=\n";
			}
			else
			{
				$mymyfmt =~ s/\@\*/%s/g;
				$mymyfmt =~ s/\@>([>]+)/
						my ($ac) = length($1);
				'%'.(2+$ac).'s'/eg;
				$mymyfmt =~ s/\@<([<]+)/
						my ($ac) = length($1);
				'%-'.(2+$ac).'s'/eg;
				$mymyfmt =~ s/\@\|([\|]+)/
						my ($ac) = length($1);
				'%-'.(2+$ac).'c'/eg;
				$mymyfmt =~ s/\@(\d*)</'%-'.(1+$1).'s'/eg;
				$mymyfmt =~ s/\@(\d*)>/'%'.(1+$1).'s'/eg;
				$mymyfmt =~ s/\@(\d*)\|/'%-'.(1+$1).'c'/eg;
				$mymyfmt =~ s/\%(\d+)([Wwc])/\%\-$1$2/g;
				$mymyfmt =~ s/\@/\%1s/g;
#print "--newfmt=$newfmt= myfmt1=$mymyfmt=\n";
				@lens = ($mymyfmt =~ /\%[\+\-]?(\d+)/g);
				@fmts = ($mymyfmt =~ /\%[^a-zA-Z]*([a-zA-Z])/g);
				@fmtjust = ($mymyfmt =~ /\%(.)/g);
				for (my $i=0;$i<=$#fmtjust;$i++)
				{
					if ($fmtjust[$i] eq '-')
					{
						$fmtjust[$i] = '<';
					}
					elsif ($fmts[$i] =~ /[c\^\|]/)
					{
						$fmtjust[$i] = '^';
					}
					else
					{
						$fmtjust[$i] = '>';
					}
				}
#print "--fmts=".join(',',@fmts).'= lens='.join(',',@lens).'=  justs='.join(',',@fmtjust);
				$mymyfmt =~ s/\\n/$myrjdelim/g;
				$mymyfmt =~ s/\\t/\t/g;
				$mymyfmt =~ s/(\%[^a-zA-Z]*)[Wwc]/$1s/g;
			}
			$mymyfmt =~ s/\x04/\@/g;
			$mymyfmt =~ s/\x03/\%/g;
			$mymyfmt =~ s/\x02/\\/g;
			$mymyfmt .= $myrjdelim;
			$fmtTextSel = $mymyfmt;
#print "--myfmt2=$mymyfmt=\n";
#print "-4- fmt=$mymyfmt= headers=$headers=\n";
			@dashes = ();
			if ($headers)
			{
				for ($i=0;$i<=$#headerlist;$i++)
				{
					$headerlist[$i] =~ s/\n/\\n/g; s/\r/\\r/g;
					$fullheaderlist[$i] = $headerlist[$i];
					$headerlist[$i] = substr($headerlist[$i],0,$lens[$i])  if ($lens[$i]);
					if ($fmts[$i] eq 'c')
					{
						$l = length($headerlist[$i]);
						$j = int(($lens[$i] - $l) / 2);
#print "h??? j=$j= l=$l= lns=$lens[$i]= f=$headerlist[$i]=\n";
						$headerlist[$i] = ' 'x$j . $headerlist[$i];
					}
					$t = $lens[$i];
					$t = length($headerlist[$i])  unless ($t);
					push (@dashes,(${myjdelim}x$t));
				}
				#open (OUTFILE,">.sqlhdr.tmp");
				#binmode OUTFILE;    #20000404
				$myfmtstmtH = &headerfmt($mymyfmt,0);
				if ($newfmt)
				{
					@l = split(/\x05/, $myfmtstmtH);
					for ($i=0;$i<=$#l;$i++)
					{
						$_ = form($l[$i], $headerlist[$i]);
						chomp  unless ($i == $#l);
						print OUTFILE;
					}
				}
				else
				{
					printf OUTFILE $myfmtstmtH, @headerlist;
				}
				++$linecnt;
				if ($myjdelim ne '')
				{
					$myfmtstmtH2 = &headerfmt($mymyfmt,1);
					if ($newfmt)
					{
						#print OUTFILE form($myfmtstmtH2, @dashes)  if ($myjdelim ne '');
						@l = split(/\x05/, $myfmtstmtH2);
						for ($i=0;$i<=$#l;$i++)
						{
							$_ = form($l[$i], $dashes[$i]);
							chomp  unless ($i == $#l);
							print OUTFILE;
						}
					}
					else
					{
						printf OUTFILE $myfmtstmtH2, @dashes  if ($myjdelim ne '');
					}
					++$linecnt;
				}
				$mypaglen = 58;
				if ($doexcel)   #ADDED 20010524!
				{
					# Create a format for the column headings.
					$excelheader = $xls->addformat();
					$excelheader->set_bold();
					#$excelheader->set_size(12);

					for $i (0..$#headerlist)
					{
						$xlssheet->write(0, $i, $fullheaderlist[$i], $excelheader);  #20010604: TRY HERE SO FULL HEADER GETS PRINTED.
						if ($types[$j] =~ /(NUM|INT|DOUBLE|FLOAT)/)
						{
							$xlssheet->set_column($i, $i, ($lens[$i]+1)); 
						}
						else
						{
							$xlssheet->set_column($i, $i, $lens[$i]); 
						}
						#$xlssheet->write(0, $i, $headerlist[$i], $excelheader);
					}
				}
			}
			else
			{
				$mypaglen = 0;
			}
			$valuestuff = $valusText->get;
			$valuestuff =~ s/\\h\=.*$//g;
			$ffchar = '';   #ADDED 20030812 TO REINITIALIZE.
			#$ffchar = $1  if ($valuestuff =~ s/(\D+)//);  #CHGD. TO NEXT 20030812.
			$ffchar = $1  if ($valuestuff =~ s/(\D+|\\x\d\d|\\0)//);
			$ffchar =~ s/\\n/\n/g;
			$ffchar =~ s/\\f/\f/g;
			$valuestuff = -1  unless ($valuestuff =~ m/\d+/);
			$valuestuff = 999999  unless ($valuestuff);
			$mypaglen = $valuestuff  if ($valuestuff >= 0);
			#select((select(OUTFILE),$- = 0)[0]);
			#select((select(OUTFILE),$= = $mypaglen)[0]);
			$reccount = 0;
			$abortit = 0;
			#while (@fieldlist = &ora_fetch($fieldcsr))
			$k = 0;
			$k++  if ($headers);
			while (@fieldlist = $fieldcsr->fetchrow_array)
			{
	              ###########DoOneEvent(1);
				$xpopup->update;
				if (($reccount % 10) == 9)
				{
					$xpopup->idletasks;
					$recLabel->configure(
							-text   => "$reccount records found so far...");
				}
				last  if ($abortit);
				&pageit;
				$maxlines = 0;

				#NOW, FILL IN LINE# IF REQUESTED ("#" IN LEU OF "@");

				$myfmtstmt = $mymyfmt;
				$myfmtstmt =~ s/\#>([>]+)/
				my ($ac) = length($1);
				'#'.(2+$ac).'s'/eg;
				$myfmtstmt =~ s/\#<([<]+)/
				my ($ac) = length($1);
				'#-'.(2+$ac).'s'/eg;
				$myfmtstmt =~ s/\#\|([\|]+)/
				my ($ac) = length($1);
				'#-'.(2+$ac).'c'/eg;
				$myfmtstmt =~ s/\#(\d*)</'#-'.(1+$1).'s'/eg;
				$myfmtstmt =~ s/\#(\d*)>/'#'.(1+$1).'s'/eg;
				$myfmtstmt =~ s/\#(\d*)\|/'#-'.(1+$1).'c'/eg;
				$myfmtstmt =~ s/\#(\d+)([Wwc])/\#\-$1$2/g;
				$myfmtstmt2 = $myfmtstmt;
				$myfmtstmt =~ s/\#([\+\-]?\d*)([a-zA-Z])/
				my ($linenosz) = $1;
				my ($linenofmt) = $2;
				$linenosz = 0  unless ($linenosz);
				$fmtreccnt = sprintf("%$linenosz$linenofmt",($reccount+1));
				$fmtreccnt/eg;
				$myfmtstmt2 =~ s/\#([\+\-]?)(\d*)[a-zA-Z]/
				my ($linesign) = $1;
				my ($linenosz) = $2;
				$linenosz = 0  unless ($linenosz);
				$fmtreccnt = sprintf("%$linesign${linenosz}s",' 'x$linenosz);
				$fmtreccnt/eg;

				foreach $i (0..$#fieldlist)
				{
					$fieldlist[$i] =~ s/\n/\\n/gs;
					$fieldlist[$i] =~ s/\r/\\r/gs;
					@{"fl$i"} = ();
					if ($fmts[$i] =~ /w/i)
					{
						$mylines = 0;
						$j = $lens[$i];
						$l = length($fieldlist[$i]);
						if ($fmts[$i] eq 'W')
						{
							$Text::Wrap::columns = $lens[$i];
							eval {$t = wrap('','',$fieldlist[$i]);};
							if ($@)
							{
								$fmts[$i] = 'w';  #WRAP CRAPPED :-(, DO MANUALLY!
							}
							else
							{
								@{"fl$i"} = split(/\n/,$t);
								#shift (@{"fl$i"});
								$mylines = $#{"fl$i"};
							}
						}
						if ($fmts[$i] eq 'w')
						{
							while ($j < $l)
							{
								push (@{"fl$i"},substr($fieldlist[$i],$j,$lens[$i]));
								$mylines += 1;
								$j += $lens[$i];
							}
						}
						$maxlines = $mylines  if ($maxlines < $mylines);
					}
					unless ($fmts[$i] eq 'W')
					{
						$sums[$i] += $fieldlist[$i] 
						if ($sumlist[$i] && $fieldlist[$i] =~ /^[\d\s\.\+\-]*$/);
						$fieldlist[$i] = substr($fieldlist[$i],0,$lens[$i])  if ($lens[$i]);
					}
					else
					{
						$fieldlist[$i] = shift (@{"fl$i"});
					}
					if ($fmts[$i] eq 'c')
					{
						$l = length($fieldlist[$i]);
						$j = int(($lens[$i] - $l) / 2);
						$fieldlist[$i] = ' 'x$j . $fieldlist[$i];
					}
				}
				;

				&pageit;
				if ($newfmt)
				{
					#print OUTFILE form($myfmtstmt,@fieldlist);
					@l = split(/\x05/, $myfmtstmt);
					for ($i=0;$i<=$#l;$i++)
					{
						$_ = form($l[$i], $fieldlist[$i]);
						chomp  unless ($i == $#l);
						print OUTFILE;
					}
				}
				else
				{
					printf OUTFILE $myfmtstmt,@fieldlist;
				}
				if ($doexcel)   #ADDED 20010524!
				{
					for $j (0..$#fieldlist)
					{

						#!!! NEED TO ADD SOME CODE TO USE FORMATS!!!

						#if ($types[$j] =~ /(NUM|INT|DOUBLE|FLOAT)/)
						if ($fmtjust[$j] eq '>')
						{
							$xlssheet->write($k, $j, $fieldlist[$j], $numericfmt);
						}
						else
						{
							$x = (length($fieldlist[$j]) > 255) ? substr($fieldlist[$j],0,255) : $fieldlist[$j];
							if ($x =~ /^\=/)
							{
								$xlssheet->write_formula($k, $j, $x, $normalfmt);
							}
							if ($x =~ m#^(?:https?\:\/\/|ftp\:\/\/|mailto\:|internal\:|external\:)#)
							{
								$xlssheet->write_url($k, $j, $x, $normalfmt);
							}
							else
							{
								$xlssheet->write_string($k, $j, $x, $normalfmt);
							}
						}
					}
					++$k;
				}
				++$linecnt;
				@l = split(/\x05/, $myfmtstmtH2)  if ($newfmt);
				for ($i=0;$i<=$maxlines-1;$i++)
				{
					&pageit;
					if ($newfmt)
					{
						#$eval = 'print OUTFILE form $myfmtstmt2,';
						for ($j=0;$j<=$#l;$j++)
						{
							$_ = form($l[$j], ${"fl$j"}[$i]);
							chomp  unless ($j >= $#l);
							print OUTFILE;
						}
					}
					else
					{
						$eval = 'printf OUTFILE $myfmtstmt2,';
						for ($j=0;$j<=$#fieldlist;$j++)
						{
							$eval .= "\${fl$j}[$i],";
						}
						chop($eval);
						eval $eval;
					}
					++$linecnt;
					if ($doexcel)   #ADDED 20010524!
					{
						for $j (0..$#fieldlist)
						{
							if ($types[$j] =~ /(NUM|INT|DOUBLE|FLOAT)/)
							{
								$xlssheet->write($k, $j, ${"fl$j"}[$i], $numericfmt);
							}
							else
							{
								$x = (length(${"fl$j"}[$i]) > 255) ? substr(${"fl$j"}[$i],0,255) : ${"fl$j"}[$i];
								if ($x =~ /^\=/)
								{
									$xlssheet->write_formula($k, $j, $x, $normalfmt);
								}
								if ($x =~ m#^(?:https?\:\/\/|ftp\:\/\/|mailto\:|internal\:|external\:)#)
								{
									$xlssheet->write_url($k, $j, $x, $normalfmt);
								}
								else
								{
									$xlssheet->write_string($k, $j, $x, $normalfmt);
								}
							}
						}
						++$k;
					}
				}
				++$reccount;
			}
			$fieldcsr->finish();
			if ($showsums)
			{
				&pageit;
				@l = split(/\x05/, $myfmtstmtH2)  if ($newfmt);
				if ($myjdelim ne '' && ($linecnt % $mypaglen) > 2)
				{
					$myfmtstmtH2 = &headerfmt($mymyfmt,1);
					if ($newfmt)
					{
						#print OUTFILE form($myfmtstmtH2, @dashes);
						for ($i=0;$i<=$#l;$i++)
						{
							$_ = form($l[$i], $dashes[$i]);
							chomp  unless ($i == $#l);
							print OUTFILE;
						}
					}
					else
					{
						printf OUTFILE $myfmtstmtH2, @dashes;
					}
					++$linecnt;
				}
				if ($newfmt)
				{
					#$eval = 'print OUTFILE form $myfmtstmt2,';
					for ($j=0;$j<=$#l;$j++)
					{
						$_ = form($l[$j], $sums[$j]);
						chomp  unless ($j >= $#l);
						print OUTFILE;
					}
				}
				else
				{
					$eval = 'printf OUTFILE $myfmtstmt2,';
					for ($j=0;$j<=$#sums;$j++)
					{
						$eval .= "\$sums\[$j\],";
					}
					chop($eval);
					eval $eval;
				}
				if ($doexcel)   #ADDED 20010524!
				{
					for $j (0..$#sums)
					{
						$xlssheet->write($k, $j, ('-' x length($sums[$j])), $numericfmt);
						$xlssheet->write($k+1, $j, $sums[$j], $numericfmt);
					}
					$k += 2;
				}
			}
			close (OUTFILE);
		}
		else
		{
			open(OUTFILE2,">.sqlout.tmp") || warn "Could not create temp. file($!)!";
			binmode OUTFILE2;    #20000404
			if ($doxml)
			{
				require MIME::Base64;
				#open (OUTFILE, ">$myfile");
				#binmode OUTFILE;
				$_ = $myselect;
#2				foreach my $i (@fieldvals)
#2				{
#2					s/\?/\'$i\'/;
#2				}
				print OUTFILE2 <<END_XML;
<?xml version="1.0" encoding="UTF-8"?>
END_XML
				print OUTFILE2 <<END_XML  if ($xsl);
<?xml-stylesheet type="text/xsl" href="$xsl"?>
END_XML
				print OUTFILE2 <<END_XML;
<database name="$dbname" user="$dbuser">
 <select query="$_">
END_XML
			}
			@fieldlist = @{$fieldcsr->{NAME}};
			if ($headers)
			{		
				@headerlist = @fieldlist;
				my $extraFields = $valusText->get;
				my @extraFieldList;
				if ($extraFields =~ s/^.*\\h=//)
				{
					@extraFieldList = split(/\,\s*/, $extraFields);
					for (my $j=0;$j<=$#extraFieldList;$j++)
					{
						$headerlist[$j] = $extraFieldList[$j]  if ($extraFieldList[$j]);
					}
				}
				#@fieldlist = &ora_titles($fieldcsr,0);
				#my (@types) = &orax_types($fieldcsr,1);
				my (@ntypes) = @{$fieldcsr->{TYPE}};
				my @types;
				my @sizes;
				foreach $i (0..$#types)
				{
					$types[$i] = &type_name($ntypes[$i]);
				}
				#@lens = &ora_lengths($fieldcsr);
				my (@lens);
				@lens = @{$fieldcsr->{PRECISION}};
				if ($dbtype eq 'Oracle')
				{
					my @oralens = @{$fieldcsr->{'ora_lengths'}};   #ORACLE-SPECIFIC.
					for (my $i=0;$i<=$#lens;$i++)
					{
						$lens[$i] ||= $oralens[$i];
					}
				}
				elsif ($dbtype eq 'mysql')
				{
					@lens = @{$fieldcsr->{mysql_length}};
				}

				my (@scales) = @{$fieldcsr->{SCALE}};
				if ($dosprite)
				{
					for $i (0..$#headerlist)
					{
						$headerlist[$i] .= '='.$types[$i].'('.$lens[$i];
						$headerlist[$i] .= ','.$scales[$i]  if ($scales[$i]);
						$headerlist[$i] .= ')';
					}
				}
				elsif ($doexcel)   #ADDED 20010524!
				{
					# Create a format for the column headings.
					$excelheader = $xls->addformat();
					$excelheader->set_bold();
					$excelheader->set_size(12);

					for $i (0..$#headerlist)
					{
						$xlssheet->write(0, $i, $headerlist[$i], $excelheader);
					}
				}
				elsif ($doxml)   #ADDED 20020612
				{
					my $orderlist = join(',', @headerlist);
###$orderlist =~ tr/a-z/A-Z/;  #TEMPORARY.   #NOT NEEDED IF SPRITE_CASEFIELDNAMES = 1!
					print OUTFILE2 <<END_XML;
  <columns order="$orderlist">
END_XML
					for $i (0..$#headerlist)
					{
						my $fieldname = $headerlist[$i];
						###$fieldname =~ tr/a-z/A-Z/;  #TEMPORARY.  #NOT NEEDED IF SPRITE_CASEFIELDNAMES = 1!
						$_ = $dB->type_info($fieldcsr->{TYPE}->[$i]);
						$sizes[$i] = ($_->{COLUMN_SIZE} || $lens[$i]);
						print OUTFILE2 <<END_XML;
   <column>
    <name>$fieldname</name>
    <type>$types[$i]</type>
    <size>$sizes[$i]</size>
    <precision>$lens[$i]</precision>
    <scale>$scales[$i]</scale>
    <nullable>NULL</nullable>
    <key>NO</key>
    <default></default>
   </column>
END_XML
					}
					print OUTFILE2 <<END_XML;
  </columns>
END_XML
				}
				$myline = join("$myjdelim",@headerlist);
				if ($myrjdelim =~ /\n$/)
				{
					$xpopupText->insert('end',"$myline$myrjdelim");
				}
				else
				{
					$xpopupText->insert('end',"$myline$myrjdelim\n");
				}
				#$xpopupText->insert('end',"$myline$/");
				#print OUTFILE2 "$myline$/";  ###if ($usrres eq $OK && $myfile =~ /\S/);
				print OUTFILE2 "$myline$/"  unless ($doxml);
			}
			$abortit = 0;
			#while (@fields = &ora_fetch($fieldcsr))
			$k = 0;
			$k++  if ($headers);
			while (@fields = $fieldcsr->fetchrow_array)
			{
				if ($doCSV)
				{
					for (my $i=0;$i<=$#fields;$i++)
					{
						$fields[$i] =~ s/\"/\"\"/gs;
						$fields[$i] = '"'.$fields[$i].'"'
								if ($fields[$i] =~ /(?:\"\"|\Q$doCSV\E)/);
					}
				}
				$xpopup->update;
				if (($reccount % 10) == 9)
				{
					$xpopup->idletasks;
					$recLabel->configure(
							-text   => "$reccount records found so far...");
				}
				last  if ($abortit);
				$myline = join("$myjdelim",@fields);
				if ($myrjdelim =~ /\n$/)
				{
					$xpopupText->insert('end',"$myline$myrjdelim");
				}
				else
				{
					$xpopupText->insert('end',"$myline$myrjdelim\n");
				}
				#$xpopupText->insert('end',"$myline$/");
				#print OUTFILE2 "$myline$/"; ###!!!!!  if (!$doexcel && $usrres eq $OK && $myfile =~ /\S/);
				print OUTFILE2 "$myline$/"  unless ($doxml);
				++$reccount;
				if ($doexcel)   #ADDED 20010524!
				{
					for $i (0..$#fields)
					{
						if ($types[$i] =~ /(NUM|INT|DOUBLE|FLOAT)/)
						{
							$xlssheet->write($k, $i, $fields[$i], $numericfmt);
						}
						else
						{
							$x = (length($fields[$i]) > 255) ? substr($fields[$i],0,255) : $fields[$i];
							$xlssheet->write($k, $i, $x, $normalfmt);
						}
					}
					++$k;
				}
				elsif ($doxml)
				{
					print OUTFILE2 <<END_XML;
  <row>
END_XML
					for $i (0..$#fields)
					{
						$_ = &xmlescape(($headerlist[$i]||$fieldlist[$i]), $fields[$i]);
						print OUTFILE2 <<END_XML;
$_
END_XML
					}
					print OUTFILE2 <<END_XML;
  </row>
END_XML
				}
			}
			$fieldcsr->finish();
			if ($doxml)
			{
				print OUTFILE2 <<END_XML;
 </select>
</database>
END_XML
			}
			close (OUTFILE2);
		}
		$xls->close()  if ($doexcel);
		if ($abortit)
		{
			$recLabel->configure(
					-text   => "ABORTED:  $reccount records found");
		}
		else
		{
			$recLabel->configure(
					-text   => "done:  $reccount records found");
		}

#2		if ($noplaceholders)
#2		{
		$statusText->insert('end',"..DID QUERY: $myselect ($reccount records selected).\n");
#2		}
#2		else
#2		{
#2			$statusText->insert('end',".......DID select $mytable with (".join(',',@fieldvals)."),  $reccount records selected.\n");
#2		}
		$statusText->see('end');
		if (open(INFILE,"<.sqlout.tmp"))
		{
			binmode INFILE;    #20000404
			if (!$doexcel && $usrres eq $OK && $myfile =~ /\S/)
			{
				open(OUTFILE2,">$myfile");
				binmode OUTFILE2;    #20000404
			}
			#$xpopupText->delete('0.0','end')  if ($usrres eq $OK && $use eq 'file');
			$xpopupText->delete('0.0','end')  if ($use eq 'file' || $doxml);
			while (<INFILE>)
			{
				s/\<select query\=\"(.*)\"\>/\<select query\=\"$1\" rows\=\"$reccount\"\>/ 
						if ($doxml);
				print OUTFILE2  if (!$doexcel && $usrres eq $OK && $myfile =~ /\S/);
				if ($mymyfmt =~ /\S/ || $use eq 'file' || $doxml)
				{
					if ($myrjdelim =~ /\n$/)
					{
						$xpopupText->insert('end',"$_");
					}
					else
					{
						$xpopupText->insert('end',"$_\n");
					}
				}
			}
			close (OUTFILE2)  if (!$doexcel && $usrres eq $OK && $myfile =~ /\S/);
			close (INFILE);
		}
		else
		{
			warn "Could not create temp. file($!)!";
		}
	}
	$/ = $slash;
	#$statusText->see('end');
}

sub doinsert
{
	#my ($i, $j, $myinsert, @myinsert, @fmtheaders, $myfile, $myline, $mybinds, @types, @lens, @myorder, @myfieldorder, @fieldvals);
	my ($i, $j, $myinsert, @myinsert, $myfile, $myline, $mybinds, @titles, @types, @lens, @myfieldorder, @fieldvals);
	my ($usrres, $abortit, $newerrorsfound, $reccount, $commitcnt, $readcnt);

	$errorsfound = 0;
	$myfile = $fileText->get;
	($mysdelim,$myjdelim) = &getdelims(0);
	my $myadelim = $adelimText->get;
	my ($myrsdelim,$myrjdelim) = &getdelims(1);  #FETCH RECORD DELIMITERS.
	my ($myasdelim,$myajdelim) = &getdelims(2);
	my ($slash) = $/;
	$/ = $myrjdelim;
	$mymyfmt = $myfmt;
	$ffchar = $1  if ($mymyfmt =~ s/^\^([\D\S]+)//);
	if ($use eq 'sql')
	{
		$myinsert = $sqlText->get('0.0','end');
		$myinsert =~ s/;+$//;
		if ($myinsert =~ /^\s*(?:drop|delete|truncate)/i)
		{
			$DIALOG2->configure(
					-text => "ABOUT TO DROP/DELETE/TRUNCATE TABLE!\nAre you SURE?");
			$usrres = $DIALOG2->Show();

			return (0)  if $usrres ne $OK;
		}
		$myinsert =~ /\btable\b\s*(\S+)/i;
		$chktable = "\U$1";
		unless ($sUperman || &chkacc("$dbname:$dbuser:$chktable",$me))
		{
			&show_err("..NOT AUTHORIZED TO ACCESS TABLE \"$chktable\"!\n");
			$/ = $slash;
			return;
		}
		#$res = &ora_do($dB,$myinsert) 
		$res = $dB->do($myinsert) 
				|| &show_err("INSERT ERROR: ".$dB->err.':'.$dB->errstr);
		$res = 'No'  if (!defined($res) || !$res || $res eq 'OK' || $res eq '0E0');
		$statusText->insert('end',"..DID: $myinsert ($res records added).\n");
		$statusText->see('end');
	}
	else
	{
		my (%typesH, %lensH, @mytypes, @mylens);
		my (@orderlist) = $orderList->get('0','end');
		@orderlist = $fieldList->get('0',$fieldList->index('end')-2)  if ($#orderlist < 0); #ADDED 11/06/96 jwt
		my (@ordbyList) = $ordbyList->get('0','end');
		my (@sequences) = split(/\,\s*/, $sqlText->get('0.0','end'));
		for ($i=0;$i<=$#sequences;$i++)
		{
			chomp($sequences[$i]);
			$sequences[$i] =~ s/\s+$//os;
		}
		my $k = 0;
		@fields = $fieldList->get('0',$fieldList->index('end')-2);
		@orderlist = @fields  unless (scalar(@orderlist));
		my $useTop2Limit = '';
		$useTop2Limit = 'top 1 '  if ($dbtype eq 'Sybase');
		if ($inscsr = $dB->prepare('select '.$useTop2Limit." * from $mytable", {ldap_sizelimit => 1, sprite_sizelimit => 1}))
		{	
			$inscsr->execute;
			&show_err("sql select: EXEC ERROR: ".$dB->err.':'.$dB->errstr)  if ($dB->err);
			#@lens = @{$inscsr->{PRECISION}};
			@titles = @{$inscsr->{NAME}};
			@types = @{$inscsr->{TYPE}};
			@lens = @{$inscsr->{PRECISION}};
			if ($dbtype eq 'Oracle')
			{
				my @oralens = @{$inscsr->{'ora_lengths'}};   #ORACLE-SPECIFIC.
				for (my $i=0;$i<=$#lens;$i++)
				{
					$lens[$i] ||= $oralens[$i];
				}
			}
			elsif ($dbtype eq 'mysql')
			{
				@lens = @{$inscsr->{mysql_length}};
			}
			$inscsr->finish;
			for (my $i=0;$i<=$#titles;$i++)
			{
				$typesH{$titles[$i]} = $types[$i];
				$lensH{$titles[$i]} = $lens[$i];
			}
		}

		$bindcnt = 0;
		$valuestuff = $valusText->get;
		$valuestuff =~ s/\\h\=.*$//g;
		if ($use eq 'line')
		{
			my (%preboundHash, @vfieldvals);
			for ($j=0;$j<=$#ordbyList;$j++)
			{
#				$mybinds .= ($sequences[$j] =~ /\S/) ? $sequences[$j] 
#						: 'NULL';
				if ($sequences[$j] =~ /\S/)
				{
					$mybinds .= $sequences[$j];
					$mybinds .= '.NEXTVAL'  unless ($mybinds =~ /\.nextval/io);
				}
				else
				{
					$mybinds .= 'NULL';
				}
				$mybinds .= ',';
			}
			if ($valuestuff =~ /\S/)
			{
				$StuffEnterred = 2;
				@vfieldvals = split($myasdelim,$valuestuff,-1);
				#@vfieldisnum = DBI::looks_like_number(@vfieldvals);
			}
			else
			{
				&inputscr(0);
			}
			for ($j=0;$j<=$#orderlist;$j++)
			{
				next  if ($orderlist[$j] eq '---filler---');
				if ($StuffEnterred == 2)    #WHERE VALUES ENTERED IN-LINE.
				{
					if (!defined $vfieldvals[$j] || $vfieldvals[$j] eq '')  #PREBIND NULL.
					{
						$mybinds .= 'NULL,';
						$preboundHash{$j} = 1;
					}
					elsif ($StuffEnterred == 2 && $vfieldvals[$j] !~ /^([\'\"]).*\1$/
							&& $vfieldvals[$j] =~ /^[A-Z_]/io)   #PREBIND FUNCTION CALLS.
					{
						$mybinds .= $vfieldvals[$j] . ',';
						$preboundHash{$j} = 1;
					}
					else
					{
						$mybinds .= '?,';             #SET UP A PLACEHOLDER.
					}
				}
				else    #WHERE VALUES ENTERED VIA PROMPT WINDOW - ALWAYS USE PLACEHOLDERS / FUNCTION CALLS NOT ALLOWED.
				{
					$mybinds .= '?,';
#					++$bindcnt;
				}
			}
			chop $mybinds;
			unless ($StuffEnterred)
			{
				$/ = $slash;
				return (0);
			}
			@fieldvals = split($myasdelim,$valuestuff,-1);
			$fieldvals[0] = ''  if ($#fieldvals < 0);
			#$myinsert = "insert into $mytable values ($mybinds)";  #CHGD. 2 NEXT 20041028.
			$myinsert = "insert into $mytable (".join(',',@ordbyList,@orderlist)
					.") values ($mybinds)";
			@myinsert = ();
			#for ($i=0;$i<=$#fields;$i++)  #CHGD. 2 NEXT 20041028.
			for ($i=0;$i<=$#orderlist;$i++)
			{
				unless ($preboundHash{$i})
				{
					$fieldvals[$i] =~ s/\x02/$myajdelim/g;  #THIS NEEDED DUE TO inputvals()!
#					if ($StuffEnterred < 2)
#					{
						$fieldvals[$i] =~ s/^[\'\"]//g;
						$fieldvals[$i] =~ s/[\'\"]$//g;
#					}
					$lensH{$orderlist[$i]} = 0  if ($typesH{$orderlist[$i]} == 9);   #SOME DBS, NAMELY PostgreSQL DON'T HAVE CORRECT VALUE HERE (USUALLY TRUNCATE INCORRECTLY TO 4).
					if ($lensH{$orderlist[$i]})
					{
						push(@myinsert,substr($fieldvals[$i],0,$lensH{$orderlist[$i]}));
						&show_err(" w:TRUNCATED1 \"".$fieldvals[$i]."\" (field# ".($i+1)." > $lensH{$orderlist[$i]} chars)!\n")
						if ($lensH{$orderlist[$i]} && length($fieldvals[$i]) > $lensH{$orderlist[$i]});
					}
					else
					{
						push(@myinsert,$fieldvals[$i]);
					}
					push (@mytypes, $typesH{$orderlist[$i]});
					push (@mylens, $lensH{$orderlist[$i]});
				}
			}

			my $myPHinsert = $myinsert;
			$statusText->insert('end',"..DOING: $myinsert\n");
			for ($i=0;$i<=$#myinsert;$i++)
			{
				if (defined $myinsert[$i])
				{
					$myinsert[$i] =~ s/\'/\'\'/g;
					##$myinsert =~ s/\?/\'$myinsert[$i]\'/;  #CHGD TO NEXT 8: 20060427 TO PREVENT ERROR!
#							if ($dbtype eq 'Sybase' && $myinsert[$i] =~ /^((?:\'\')?)[\d\.\+\-]+\1$/)
#							if ($dbtype eq 'Sybase' && (($mytypes[$i] >= 2 && $mytypes[$i] <= 8) || $mytypes[$i] == 1700 || $mytypes[$i] == -5 || $mytypes[$i] == -6))
					if ($myinsert[$i] eq '')
					{
						$myinsert =~ s/\?/NULL/;
					}
#					elsif ($StuffEnterred == 2)
#					{
#						$myinsert =~ s/\?/$myinsert[$i]/;
#					}
					elsif (($mytypes[$i] >= 2 && $mytypes[$i] <= 8) 
							|| $mytypes[$i] == 1700 || $mytypes[$i] == -5 
							|| $mytypes[$i] == -6)
					{
						$myinsert[$i] =~ s/^\'\'(.*)\'\'$/\'$1\'/;
						$myinsert =~ s/\?/$myinsert[$i]/;
					}
					else
					{
						$myinsert =~ s/\?/\'$myinsert[$i]\'/;
					}
				}
				else
				{
					$myinsert =~ s/\?/NULL/s;
				}
			}
			if ($noplaceholders)
			{
				$res = $dB->do($myinsert)	
						|| &show_err(" INSERT ERROR: ".$dB->err.':'.$dB->errstr);
				unless ($dB->err)  #SYBASE/TDS ALWAYS SEEMS TO RETURN -1!
				{
					$res = '1 or more'  if ($res < 0);
				}
			}
			else
			{
				$res = $dB->do($myPHinsert,{},@myinsert)	
						|| &show_err(" INSERT ERROR: ".$dB->err.':'.$dB->errstr);

			}
			$res = 'No'  if (!defined($res) || $res <= 0);
#2			$statusText->insert('end',".......DID: insert into $mytable with (".join(',',@myinsert)."), ($res records added).\n");
#2				$statusText->insert('end',"***** ".$dB->err.': '.$dB->errstr)  if ($dB->err);
#2			if ($noplaceholders)
#2			{
				$statusText->insert('end',".......DID: $myinsert ($res records added).\n");
#2			}
#2			else
#2			{
#2				$statusText->insert('end',".......DID: insert into $mytable with (".join(',',@myinsert)."), ($res records added).\n");
#2			}
			$statusText->update;
			$statusText->see('end');
		}
		else
		{
			my @colorder;
my @fnvals = split($myasdelim,$valuestuff,-1);
			$xls = undef;
			$xlssheet = undef;

			#OPEN UP THE INPUT SOURCE FILE.

			if ($myfile =~ /\.xls/i)
			{
				if ($noexcelin)
				{
					&show_err("\"$myfile\" is an Excel spreadsheet and \"Spreadsheet::ParseExcel::Simple\" module not loaded!");
					return 0;
				}
				$xls = Spreadsheet::ParseExcel::Simple->read($myfile);
				unless ($xls)
				{
					&show_err(" Could not open \"$myfile\" as Excel spreadsheet ($@)!");
					return 0;
				}
				my @sheets = $xls->sheets;
				$xlssheet = $sheets[0];
				unless ($xlssheet)
				{
					&show_err(" Could not open 1st sheet of \"$myfile\" as Excel spreadsheet ($@)!");
					return 0;
				}
			}
			else
			{
				if (open(INFILE,"<$myfile"))
				{
					binmode INFILE;
				}
				else
				{
					&show_err("..Couldn't open flatfile \"$myfile\" for input ($?)!\n");
					return 0;
				}
			}
			
			#SET UP INDEX ARRAYS FOR FIELD ORDERING.

			for ($i=0;$i<=$#fields;$i++)
			{
				for ($j=0;$j<=$#orderlist;$j++)
				{
					next  if ($orderlist[$j] eq '---filler---');
					if ($fields[$i] eq $orderlist[$j])
					{
						$myfieldorder[$j] = $i;
					}
				}
			}
			my (@mytitles, @mytypes, @mylens);
			for ($j=0;$j<=$#orderlist;$j++)
			{
				next  if ($orderlist[$j] eq '---filler---');   #???
				push (@mytitles, $titles[$myfieldorder[$j]]);
				push (@mytypes, $types[$myfieldorder[$j]]);
				push (@mylens, $lens[$myfieldorder[$j]]);
			}
			$j = 0;
#			@fmtheaders = ();  #ADDED 20030521 TO FIX BUG PRODUCING GARBAGE FOR FIELD NAMES IN GENERATED SQLTEMP.PL COMMENTS.
			if ($headers)
			{
				if ($xlssheet)
				{
					$xlssheet->next_row  if ($xlssheet->has_data);
				}
				else
				{
					$_ = <INFILE>;
					s/^\s+//;
#					@fmtheaders = split(/\s+/, $_);
				}
			}
			my @timestuff = localtime(time);
			my ($today);
			$today = '0'  if ($timestuff[4] < 9);
			$today .= $timestuff[4] + 1;
			$today .= '/';
			$today .= '0'  if ($timestuff[3] < 10);
			$today .= $timestuff[3];
			$today .= '/';
			$today .= $timestuff[5] + 1900;

			my $batchcodePre = <<END_CODE;
#!/usr/bin/perl

### THIS CODE AUTO-GENERATED $today BY SQL-PERL PLUS v. $vsn TO BACH-LOAD 
###    DATA INTO TABLE "$mytable", 
###    OF "$dbtype" DATABASE "$dbname".

unless (\$ARGV[0] && \$ARGV[0] !~ /\-\-/i)
{
	print <<END_MSG;
..usage: \$0 <textfile> [new]
..loads data from <textfile> into table \"$mytable\" 
	of \"$dbtype\" database \"$dbname\".
END_MSG
	exit (0);
}

use DBI;
END_CODE

			if ($xlssheet)
			{
				$batchcodePre .= <<END_CODE;
use Spreadsheet::ParseExcel::Simple;

#print STDERR "..Opening spreadsheet file for input, please wait..";

my \$xls = Spreadsheet::ParseExcel::Simple->read(\$ARGV[0]);
die ("Could not open \\"\$ARGV[0]\\" as Excel spreadsheet (\$@)!\\n")
		unless (\$xls);
my \@sheets = \$xls->sheets;
my \$xlssheet = \$sheets[0];
die ("Could not open 1st sheet of \\"\$ARGV[0]\\" as Excel spreadsheet ($@)!\\n")
		unless (\$xlssheet);
END_CODE
			}
			else
			{
				$batchcodePre .= <<END_CODE;
open (INFILE, "<\$ARGV[0]") || die ("Could not open input file (\$ARGV[0])!\\n");
binmode INFILE;
END_CODE
			}
			
			$batchcodePre .= <<END_CODE;
my \$inscsr;
my \$dB=DBI->connect('$connectstr', '$dbuser', '$dbpswd', {$attb}) 
		|| die ('Could not connect('.DBI->err.':'.DBI->errstr.")!\\n");
\$dB->{AutoCommit} = $dB->{AutoCommit};
END_CODE
			$batchcodePre .= "\$dB->do('set TEXTSIZE 65535');  #NEEDED FOR SYBASE.\n"  if ($dbtype eq 'Sybase');  #ADDED 20030131 TO FIX "OUT OF MEMORY" ERRORS ON SELECTS FROM SQL-SERVER TABLES.
			$batchcodePre .= "\$dB->{LongTruncOk} = 1;   #NEEDED FOR ODBC.\n"  if ($dbtype eq 'ODBC');      #ODBC.

			unless ($xlssheet)
			{
				my $hexvals = unpack('H*',$myrjdelim);
				$hexvals =~ s/([0-9a-f][0-9a-f])/\\x$1/gs;
				$batchcodePre .= <<END_CODE;
\$/ = "$hexvals";
END_CODE
			}

			$batchcodePre .= <<END_CODE;

if (\$ARGV[1] =~ /new/i)
{
	print STDERR "..deleting existing records..\n";
	\$inscsr = \$dB->prepare('delete from $mytable')
			|| die ('Could not prepare ('.\$dB->err.':'.\$dB->errstr.")!\\n");
	\$inscsr->execute() 
			|| die ('Could not execute delete ('.\$dB->err.':'.\$dB->errstr.")!\\n");
	\$inscsr->finish();
	\$dB->commit()  unless (\$dB->{AutoCommit});
}

END_CODE
			$batchcode = ($noplaceholders) ? "my \$insstr = \"" : "\$inscsr = \$dB->prepare(\"";
			$myinsert = "insert into $mytable (".join(',',@ordbyList).',';
			$batchcode =~ s/\(\,$/\(/o;
			$myinsert =~ s/\(\,$/\(/o;
			for (my $i=0;$i<=$#orderlist;$i++)
			{
				next  if ($orderlist[$i] eq '---filler---');
				$myinsert .= $orderlist[$i] . ',';
			}
			$myinsert =~ s/\,$//o;
			$myinsert .= ') values (';
			for (my $i=0;$i<=$#ordbyList;$i++)
			{
				if ($sequences[$j] =~ /\S/)
				{
					$myinsert .= $sequences[$j];
					$myinsert .= '.NEXTVAL'  unless ($myinsert =~ /\.nextval/io);
				}
				else
				{
					$myinsert .= 'NULL';
				}
			}
			my (@mytypes2, @mylens2);   #USED FOR BATCHCODE, CORRESPOND TO COLORDER.
			my $nextArg = 0;            #CURRENT POSITION IN FIELD LIST.
			for (my $i=0;$i<=$#orderlist;$i++)
			{
				next  if ($orderlist[$i] eq '---filler---');
				if (defined($fnvals[$myfieldorder[$i]]) && length($fnvals[$myfieldorder[$i]]) > 0)
				{
					my $fnval = $fnvals[$myfieldorder[$i]];
					while ($fnval =~ s/(.+)\:(\d+)/$1\?/)
					{
						my ($one, $two) = ($1, $2);
						if ($one =~ /([\'\"])$/)
						{
							my $quotechar = $1;
							push (@mytypes2, 1);   #A STRING TYPE.
							push (@mylens2, 32767);
							$fnval =~ s/$quotechar\?$quotechar/\?/; #  unless ($noplaceholders);   #MUST CONVERT '?' TO ? FOR BINDS!
						}
						else
						{
							push (@mytypes2, 2);    #A NUMERIC TYPE.
							push (@mylens2, 255);
						}
						push (@colorder, $two);
					}
					$myinsert .= $fnval;
				}
				else
				{
					$myinsert .= '?';
					push (@mytypes2, $mytypes[$nextArg]);
					push (@mylens2, $mylens[$nextArg]);
					push (@colorder, $i);
				}
				$myinsert .= ', ';
				++$nextArg;
			}
			chop ($myinsert);
			chop ($myinsert);
			$myinsert .= ')';
			$statusText->insert('end',"..DOING: $myinsert\n");
			$statusText->see('end');
			$batchcode .= $myinsert;
			if ($noplaceholders)
			{
				$batchcode .= "\";\n";
				$batchcode .= "my \$inssql = \$insstr;\n";
			}
			else
			{
				$batchcode .= "\") \n";
				$batchcode .= <<END_CODE;
			|| die ('Could not prepare ('.\$dB->err.':'.\$dB->errstr.")!\\n");
END_CODE
			}
			$batchcode .= "my \@types = (".join(',', @mytypes2).");\n";
			$batchcode .= "my \@lens = (".join(',', @mylens2).");\n";
			$batchcode .= "my \@colorder = (".join(',', @colorder).");\n";
			$batchcode .= "my (\@infieldvals, \@fieldvals);\n";
			$batchcode .= <<END_CODE;
my \$cnt = 0;
my \$reccnt = 0;
my \$errwarncnt = '0';
my \$rowhasdata = 0;
END_CODE
			if (!$xlssheet && $mymyfmt =~ /\S/)
			{
				$batchcode .= "my \@leftjust = ('<InsertLeftJustValueHere!>');\n";
			}
			$batchcode .= <<END_CODE;

print STDERR "..inserting records, please wait..\\n";
END_CODE
			if ($headers)
			{
				if ($xlssheet)
				{
					$batchcode .= <<END_CODE;
\$xlssheet->next_row  if (\$xlssheet->has_data);
\$cnt++;
END_CODE
				}
				else
				{
					$batchcode .= <<END_CODE;
<INFILE>;     #SKIP FIRST RECORD SINCE IT IS A HEADER RECORD.
\$cnt++;
END_CODE
				}
			}
			if ($xlssheet)
			{
				$batchcode .= <<END_CODE;
while (\$xlssheet->has_data)
{
	\@infieldvals = \$xlssheet->next_row;
	++\$cnt;
	\$rowhasdata = 0;
	for (my \$i=0;\$i<=\$#infieldvals;\$i++)
	{
		if (length(\$infieldvals[\$i]) > 0)
		{
			\$rowhasdata = 1;
			last;
		}
	}
	next  unless (\$rowhasdata);

	\@fieldvals = ();
	for (my \$i=0;\$i<=\$#colorder;\$i++)
	{
		if (\$types[\$i] >= 2 && \$types[\$i] <= 8)
		{
			\$infieldvals[\$colorder[\$i]] =~ s/\-\-/\-/;  #FIX PARSEEXCEL BUG!
		}
		if (length(\$infieldvals[\$colorder[\$i]]) > \$lens[\$i])
		{
			warn (" w:(rec#\$cnt) TRUNCATED \\"".\$infieldvals[\$colorder[\$i]]."\\" (field# ".(\$i+1)." > \$lens[\$i] chars)!");
			\$infieldvals[\$colorder[\$i]] = substr(\$infieldvals[\$colorder[\$i]],0,\$lens[\$i]);
			++\$errwarncnt;
		}
END_CODE
				if ($noplaceholders)
				{
						$batchcode .= <<END_CODE;
		if (\$infieldvals[\$colorder[\$i]] eq '')
		{
			\$inssql =~ s/\\?/NULL/;
			push (\@fieldvals, 'NULL');
		}
		elsif ((\$types[\$i] >= 2 
				&& \$types[\$i] <= 8) 
				|| \$types[\$i] == 1700
				|| \$types[\$i] == -5
				|| \$types[\$i] == -6)
		{
			\$infieldvals[\$colorder[\$i]] =~ s/^\\'\\'\?(.*)\\'\\'\?\$/\$1/;
			\$inssql =~ s/\\?/\$infieldvals[\$colorder[\$i]]/;
			push (\@fieldvals, \$infieldvals[\$colorder[\$i]]);
		}
		else
		{
			\$inssql =~ s/\\?/\'\$infieldvals[\$colorder[\$i]]\'/;
			push (\@fieldvals, "\'\$infieldvals[\$colorder[\$i]]\'");
		}
END_CODE
				}
				else
				{
					$batchcode .= "		push (\@fieldvals, \$infieldvals[\$colorder[\$i]]);\n";
				}
				$batchcode .= <<END_CODE;
	}
END_CODE
			}
			else
			{
				$batchcode .= <<END_CODE;
while (<INFILE>)     #READ RECORDS FROM INPUT FILE.
{
	++\$cnt;
print "--- cnt=\$cnt= ab=\$abortit= line=\$_=\\n";  #DEBUG!
	\@infieldvals = ();
	\@fieldvals = ();
END_CODE
				$batchcode .= "	next  if (/^$ffchar/);\n"  if ($ffchar && $headers);
				if ($mymyfmt =~ /\S/)
				{
					$batchcode .= "	next  if (/^(?:$mysdelim|\\s)+\$/);\n"  if ($headers && $myjdelim =~ /\S/);    #YES, THIS NEEDS TO BE mySdelim TO ESCAPE SPECIAL CHARS!
					@fmtblks = ($mymyfmt =~ /(.*?\@(?:\d+[\<\|\>])?)/g);
					@fmtlens = ();
					@start = ();
					@fmtjust = ();
					$start = 0;
					for (my $i=0;$i<=$#fmtblks;$i++)
					{
						if ($fmtblks[$i] =~ /(.*)\@(\d+)(.)/)
						{
							$fmtblk = length($1);
							$fmtlens[$i] = $2;
							++$fmtlens[$i];
							$start += $fmtblk;
							$start[$i] = $start;
							$start += $fmtlens[$i];
							$fmtjust[$i] = $3;
						}
						elsif ($fmtblks[$i] =~ /(.*)\@/)
						{
							$fmtblk = length($1);
							$fmtlens[$i] = 1;
							$start += $fmtblk;
							$start[$i] = $start;
							$start++;
							$fmtjust[$i] = '>';
						}
						#CHGD. TO NEXT 2 20030620 TO PREVENT GARBAGE IN HEADER 
						#COMMENT FIELDS IN GENERATED SQLTEMP.PL
#						$batchcode .= "\n	#Field: \"" 
#								. ($fmtheaders[$i]  || $orderlist[$i] || "--UNUSED--");
						$batchcode .= "\n	#Field: \"" 
								. ($orderlist[$i] || "--UNUSED--");
						$batchcode .= "\".\n";
						$batchcode .= "	\$x = substr(\$_,$start[$i],$fmtlens[$i]);\n";
###########						$batchcode .= "	\$x =~ s/^\\s+//;\n"  if ($types[$i] != 1 && $fmtjust[$i] ne '<');
###########						$batchcode .= "	\$x =~ s/\\s+\$//;\n"  if ($types[$i] != 1);
#$batchcode .= "###### TYPE=$types[$i]= lens=$lens[$i]= i=$i= field=$orderlist[$i]=\n";
						$batchcode .= "	push (\@infieldvals, \$x);\n";
					}
					if (!$xlssheet)
					{
						my $bc;
						for (my $i=0;$i<=$#fmtblks;$i++)
						{
							$bc .= ($fmtjust[$i] eq '<' || ($mytypes[$i] >= 2 && $mytypes[$i] <= 8) 
							|| $mytypes[$i] == 1700 || $mytypes[$i] == -5 
							|| $mytypes[$i] == -6) ? '1,' : '0,';
						}
						chop ($bc);
						$batchcode =~ s/\'\<InsertLeftJustValueHere\!\>\'/$bc/;
					}
					$batchcode .= <<END_CODE;
	for (my \$i=0;\$i<=\$#colorder;\$i++)
	{
		if (\$types[\$i] != 1)
		{
			\$infieldvals[\$colorder[\$i]] =~ s/^\\s+//  if (\$leftjust[\$colorder[\$i]]);
			\$infieldvals[\$colorder[\$i]] =~ s/\\s+\$//;
		}
END_CODE
					if ($noplaceholders)
					{
						$batchcode .= <<END_CODE;
		if (\$infieldvals[\$colorder[\$i]] eq '')
		{
			\$inssql =~ s/\\?/NULL/;
			push (\@fieldvals, 'NULL');
		}
		elsif ((\$types[\$i] >= 2 
				&& \$types[\$i] <= 8) 
				|| \$types[\$i] == 1700
				|| \$types[\$i] == -5
				|| \$types[\$i] == -6)
		{
			\$infieldvals[\$colorder[\$i]] =~ s/^\\'\\'\?(.*)\\'\\'\?\$/\$1/;
			\$inssql =~ s/\\?/\$infieldvals[\$colorder[\$i]]/;
			push (\@fieldvals, \$infieldvals[\$colorder[\$i]]);
		}
		else
		{
			\$inssql =~ s/\\?/\'\$infieldvals[\$colorder[\$i]]\'/;
			push (\@fieldvals, "\'\$infieldvals[\$colorder[\$i]]\'");
		}
END_CODE
					}
					else
					{
						$batchcode .= "		push (\@fieldvals, \$infieldvals[\$colorder[\$i]]);\n";
					}
					$batchcode .= <<END_CODE;
	}
END_CODE
				}
				elsif ($myjdelim =~ /^\"(\S+)\"$/)  #20030811: HANDLE CSV FILES!
				{
					my $mysdelimchar = $1;
					$batchcode .= <<END_CODE;
	chomp;
	next  unless (\$_);   #SKIP COMPLETELY BLANK LINES.
	s/\\"\\"/\\x02\\^1jSpR1tE\\x02/gs;   #PROTECT QUOTE PAIRS (QUOTES ARE ESCAPED BY PARING)
	s/\\"([^\\"]*?)\\"/
			my (\$str) = \$1;
			\$str =~ s|\Q$mysdelimchar\E|\\x02\\^2jSpR1tE\\x02|gs;   #PROTECT COMMAS IN QUOTES.
			"\\"\$str\\""/egs;

	\@infieldvals = split(/\\$mysdelimchar/,\$_,-1);
	for (my \$i=0;\$i<=\$#colorder;\$i++)
	{
		\$infieldvals[\$colorder[\$i]] =~ s/\\"//gs;   #REMOVE THE BOUNDING QUOTES
		\$infieldvals[\$colorder[\$i]] =~ s/\\x02\\^2jSpR1tE\\x02/\\$mysdelimchar/gs;  #UNPROTECT COMMAS.
		\$infieldvals[\$colorder[\$i]] =~ s/\\x02\\^1jSpR1tE\\x02/\\"/gs;  #UNPROTECT QUOTES.
		if (length(\$infieldvals[\$colorder[\$i]]) > \$lens[\$i])
		{
			warn (" w:(rec#\$cnt) TRUNCATED \\"".\$infieldvals[\$colorder[\$i]]."\\" (field# ".(\$i+1)." > \$lens[\$i] chars)!");
			\$infieldvals[\$colorder[\$i]] = substr(\$infieldvals[\$colorder[\$i]],0,\$lens[\$i]);
			++\$errwarncnt;
		}
END_CODE
					if ($noplaceholders)
					{
						$batchcode .= <<END_CODE;
			if (\$infieldvals[\$colorder[\$i]] eq '')
			{
				\$inssql =~ s/\\?/NULL/;
				push (\@fieldvals, 'NULL');
			}
			elsif ((\$types[\$i] >= 2 
					&& \$types[\$i] <= 8) 
					|| \$types[\$i] == 1700
					|| \$types[\$i] == -5
					|| \$types[\$i] == -6)
			{
				\$infieldvals[\$colorder[\$i]] =~ s/^\\'\\'\?(.*)\\'\\'\?\$/\$1/;
				\$inssql =~ s/\\?/\$infieldvals[\$colorder[\$i]]/;
				push (\@fieldvals, \$infieldvals[\$colorder[\$i]]);
			}
			else
			{
				\$inssql =~ s/\\?/\'\$infieldvals[\$colorder[\$i]]\'/;
				push (\@fieldvals, "\'\$infieldvals[\$colorder[\$i]]\'");
			}
END_CODE
					}
					else
					{
						$batchcode .= "			push (\@fieldvals, \$infieldvals[\$colorder[\$i]]);\n";
					}
					$batchcode .= <<END_CODE;
	}
END_CODE
				}
				else
				{
					$batchcode .= <<END_CODE;
	chomp;
	next  unless (\$_);   #SKIP COMPLETELY BLANK LINES.
	\@infieldvals = split(/$mysdelim/,\$_,-1);
	for (my \$i=0;\$i<=\$#colorder;\$i++)
	{
		if (length(\$infieldvals[\$colorder[\$i]]) > \$lens[\$i])
		{
			warn (" w:(rec#\$cnt) TRUNCATED \\"".\$infieldvals[\$colorder[\$i]]."\\" (field# ".(\$i+1)." > \$lens[\$i] chars)!");
			\$infieldvals[\$colorder[\$i]] = substr(\$infieldvals[\$colorder[\$i]],0,\$lens[\$i]);
			++\$errwarncnt;
		}
END_CODE
					if ($noplaceholders)
					{
						$batchcode .= <<END_CODE;
		if (\$infieldvals[\$colorder[\$i]] eq '')
		{
			\$inssql =~ s/\\?/NULL/;
			push (\@fieldvals, 'NULL');
		}
		elsif ((\$types[\$i] >= 2 
				&& \$types[\$i] <= 8) 
				|| \$types[\$i] == 1700
				|| \$types[\$i] == -5
				|| \$types[\$i] == -6)
		{
			\$infieldvals[\$colorder[\$i]] =~ s/^\\'\\'\?(.*)\\'\\'\?\$/\$1/;
			\$inssql =~ s/\\?/\$infieldvals[\$colorder[\$i]]/;
			push (\@fieldvals, \$infieldvals[\$colorder[\$i]]);
		}
		else
		{
			\$inssql =~ s/\\?/\'\$infieldvals[\$colorder[\$i]]\'/;
			push (\@fieldvals, "\'\$infieldvals[\$colorder[\$i]]\'");
		}
END_CODE
					}
					else
					{
						$batchcode .= "		push (\@fieldvals, \$infieldvals[\$colorder[\$i]]);\n";
					}
					$batchcode .= <<END_CODE;
	}
END_CODE
#1	1 while (\$inssql =~ s/\\:(\\d+)/\$infieldvals[\$1]/);
				}
			}
			if ($noplaceholders)
			{
				$batchcode .= <<END_CODE;
	if (\$inscsr = \$dB->prepare(\$inssql))
	{
		if (\$inscsr->execute())
		{
			\$inscsr->finish();
		}
		else
		{
			warn ('Could not execute record# '.(\$reccnt+1).' ('.\$dB->err.':'.\$dB->errstr.')!');
			++\$errwarncnt;
		}
	}
	else
	{
		warn ('Could not prepare record# '.(\$reccnt+1).' ('.\$dB->err.':'.\$dB->errstr.')!');
		++\$errwarncnt;
	}
	\$inssql = \$insstr;
END_CODE
			}
			else
			{
				$batchcode .= <<END_CODE;
	\$inscsr->execute(\@fieldvals) 
			|| (warn ('Could not execute record# '.(\$reccnt+1).' ('.\$dB->err.':'.\$dB->errstr.')!') && ++\$errwarncnt);
	\$inscsr->finish();
END_CODE
			}
			$batchcode .= "	++\$reccnt;\n";
			$batchcode .= "	\$dB->commit()  unless (\$dB->{AutoCommit} || \$reccnt % 20);\n";
			$batchcode .= <<END_CODE;
}
\$inscsr->finish();
\$dB->commit()  unless (\$dB->{AutoCommit});
close INFILE;
\$dB->disconnect();
print STDERR "..done: \$cnt lines read, ".(\$reccnt)." records added to \\\"$mytable\\\" from file: \\\"\$ARGV[0]\\\"; \$errwarncnt errors/warnings!\\n";
exit (0);

END_CODE
			$batchcodePre .= $batchcode;
			$batchcode =~ s/exit \(0\)\;/\#exit \(0\)\;/gso;
			$batchcode =~ s/\+\+\$cnt\;/\+\+\$cnt\;\n\tlast  if \(\$abortit\)\;/so;
			$batchcode =~ s/warn \(/\&show_err\(/gso;
			$batchcode =~ s/\t\+\+\$reccnt;/
\t\$statusText\-\>insert\(\'end\'\,\"\.\.\.\.\.\.\.DID\(\$reccnt\)\: insert into \$mytable with \(\"\.join(\'\,\'\,\@fieldvals\)\.\"\)\.\\n\"\)\;
\t\+\+\$reccnt\;
\t\+\+\$commitcnt\;
/so;
			$batchcode =~ s/\t\$dB\-\>commit\(\)  unless \(\$dB\-\>\{AutoCommit\} \|\| \$reccnt \% 20\)\;/
\t\$statusText\-\>see\(\'end\'\)\;
\tunless \(\$reccnt \% 20\)
\t\{
\t\tif \t(\$newerrorsfound \|\| \(\$usrres ne \$OkAll \&\& \$nocommit \=\= 1\)\)
\t\t\{
\t\t\t\$usrres \= \$DIALOG3\-\>Show\(\'$showgrabopt\'\)\;
\t\t\t\$newerrorsfound \= 0\;
\t\t\}
\t\telse
\t\t\{
\t\t\t\$usrres \= \$OkAll\;
\t\t\}
\t\tif \(\$usrres eq \$Cancel\)
\t\t\{
\t\t\tif \(\$nocommit \< 2\)
\t\t\t\{
\t\t\t\t\&dorollback\(\)\;
\t\t\t\t\$commitcnt \= 0\;
\t\t\t\}
\t\t\tlast\;
\t\t\}
\t\t\&docommit\(\)  if \(\$nocommit \< 2\)\;
\t\t\$reccount \+\= \$commitcnt\;
\t\t\$commitcnt \= 0\;
\t}
/so;
			$batchcode =~ s/close INFILE;/close INFILE;
if \(\!\$abortit \&\& \$nocommit \< 2\)
\{
\tif \(\$commitcnt \&\& \(\$newerrorsfound \|\| \(\$usrres ne \$OkAll \&\& \$nocommit \=\= 1\)\)\)
\t\{
\t\t\$usrres \= \$DIALOG3\-\>Show\(\'$showgrabopt\'\)\;
\t\t\$newerrorsfound \= 0\;
\t\}
\telse
\t\{
\t\t\$usrres \= \$OkAll\;
\t\}
\tif \(\$usrres eq \$Cancel\)
\t\{
\t\tif \(\$nocommit \< 2\)
\t\t\{
\t\t\t\&dorollback\(\)\;
\t\t\t\$commitcnt \= 0\;
\t\t\}
\t\}
\telse
\t\{
\t\t\&docommit\(\)\;
\t\}
\}
\$reccount \+\= \$commitcnt\;
\$statusText\-\>insert\(\'end\'\,\"\.\.\.\.\.\.\.inserted \$reccount records into \$mytable\, \$errorsfound errors\/warnings\.\\n\"\)\;
\$statusText\-\>see\(\'end\'\)\;
/so;
			$abortit = 0;
			$newerrorsfound = 0;
			$commitcnt = 0;
			$readcnt = 0;
			$reccount = 0;
			$commitcnt = 0;
			$usrres = '';

			open (OUTFILE2, ">sqltemp.pl");
			binmode OUTFILE2;    #20000404
			print OUTFILE2 $batchcode;
			close OUTFILE2;
			open (OUTFILE2, ">sqltemppre.pl");
			binmode OUTFILE2;    #20000404
			print OUTFILE2 $batchcodePre;
			close OUTFILE2;

			eval $batchcode;
			&show_err($@)  if ($@);
		}
	}
	$/ = $slash;
}

sub doupdate
{
	my ($i, $j, $item, $myupdate, @myupdate, $myfile, $myline, $mybinds, $setstuff, $found, @fieldvals, @lens);
	my ($bindcnt, @wherebits, @extravals, $addand, @myorder1, @myorder2, @titles, @types);
	my ($updcsr);

	$myfile = $fileText->get;
	($mysdelim,$myjdelim) = &getdelims(0);
	my ($myrsdelim,$myrjdelim) = &getdelims(1);  #FETCH RECORD DELIMITERS.
	my ($slash) = $/;
	$/ = $myrjdelim;
	$errorsfound = 0;
	$addand = 0;
	$bindcnt = 0;
	@extravals = ();
	$mymyfmt = $myfmt;
	$ffchar = $1  if ($mymyfmt =~ s/^\^([\D\S]+)//);

	if ($use eq 'sql')
	{
		$myupdate = $sqlText->get('0.0','end');
		$myupdate =~ s/;+$//;
		if ($myupdate =~ /^\s*(?:drop|delete|truncate)/i)
		{
			$DIALOG2->configure(
					-text => "ABOUT TO DROP/DELETE/TRUNCATE TABLE!\nAre you SURE?");
			my ($usrres) = $DIALOG2->Show();

			return (0)  if $usrres ne $OK;
		}
		$myupdate =~ /\btable\b\s*(\S+)/i;
		$chktable = "\U$1";
		unless ($sUperman || &chkacc("$dbname:$dbuser:$chktable",$me))
		{
			&show_err("..NOT AUTHORIZED TO ACCESS TABLE \"$chktable\"!\n");
			$/ = $slash;
			return;
		}
		#$res = &ora_do($dB,$myupdate) || &show_err(" UPDATE ERROR: ".$dB->err.':'.$dB->errstr);
		$res = $dB->do($myupdate) || &show_err(" UPDATE ERROR: ".$dB->err.':'.$dB->errstr);
		#$res = 'No'  if (!defined($res) || !$res || $res eq 'OK' || $res eq '0E0');
		if ($res)
		{
			#$res = $dB->rows;
			$res ||= $DBI::rows;
		}
		else
		{
			$res = 'No';
		}
		chomp($myupdate);
		$statusText->insert('end',"..DID: $myupdate ($res records updated).\n");
		$statusText->see('end');
	}
	else
	{
		my (%typesH, %lensH, @mytypes, @mylens);
		my (@orderlist) = $orderList->get('0','end');
		my (@ordbyList) = $ordbyList->get('0','end');
		@orderlist = $fieldList->get('0',$fieldList->index('end')-2)  if ($#orderlist < 0); #ADDED 11/06/96 jwt
		@fields = $fieldList->get('0',$fieldList->index('end')-2);
		$wherestuff = $sqlText->get('0.0','end');
		$wherestuff =~ s/\n//g;
		@ops = ();
		@relops = ();
		my (@wherelist) = $whereList->get('0','end');
		my (@lens);   #MOVED OUT OF IF 20000515
		$useTop2Limit = 'top 1 '  if ($dbtype eq 'Sybase');
		if ($updcsr = $dB->prepare("select ".$useTop2Limit." * from $mytable"))
		{
			$updcsr->execute;
			&show_err("sql select: EXEC ERROR: ".$dB->err.':'.$dB->errstr)  if ($dB->err);
			@titles = @{$updcsr->{NAME}};
			@types = @{$updcsr->{TYPE}};
			@lens = @{$updcsr->{PRECISION}};
			if ($dbtype eq 'Oracle')
			{
				my @oralens = @{$updcsr->{'ora_lengths'}};   #ORACLE-SPECIFIC.
				for (my $i=0;$i<=$#lens;$i++)
				{
					$lens[$i] ||= $oralens[$i];
				}
			}
			elsif ($dbtype eq 'mysql')
			{
				@lens = @{$updcsr->{mysql_length}};
			}
			$updcsr->finish;
			for (my $i=0;$i<=$#titles;$i++)
			{
				$typesH{$titles[$i]} = $types[$i];
				$lensH{$titles[$i]} = $lens[$i];
			}
		}
		$myupdate = "update $mytable set ";
		@mytypes = ();
		@mylens = ();
		$StuffEnterred = 0;
		if ($use eq 'line')
		{
			my (@vfieldvals);
			$valuestuff = $valusText->get;
			$valuestuff =~ s/\\h\=.*$//g;
			if ($valuestuff =~ /\S/)
			{
				$StuffEnterred = 2;
			}
			else
			{
				&inputscr(0);
			}
			unless ($StuffEnterred)
			{
				$/ = $slash;
				return (0);
			}
			@vfieldvals = split($myasdelim,$valuestuff,-1);
			$vfieldvals[0] = ''  if ($#vfieldvals < 0);
			#my @isNumeric = DBI::looks_like_number(@vfieldvals);
			for ($i=0;$i<=$#orderlist;$i++)
			{
				if ($StuffEnterred == 2 && $vfieldvals[$i] !~ /^([\'\"]).*\1$/
						&& $vfieldvals[$i] =~ /^[A-Z_]/io)
				{
					$myupdate .= $orderlist[$i] . ' = ' . $vfieldvals[$i];
				}
				else
				{
					++$bindcnt;
					$myupdate .= "$orderlist[$i] = ?";
					push (@fieldvals, $vfieldvals[$i]);
					push (@mytypes, $typesH{$orderlist[$i]});
					push (@mylens, $lensH{$orderlist[$i]});
				}
				$myupdate .= ','  unless ($i == $#orderlist);
			}
			if ($wherestuff =~ /\S/ && $#wherelist < 0)  #STUFF IN SQL TEXT BUT NOTHIN IN WHERE LIST.
			{
				#TREAT WHERE STUFF AS COMPLETE WHERE-CLAUSE.

				$myupdate .= ' where ' . $wherestuff;
				$wherestuff = '';
			}
			elsif ($#wherelist >= 0)
			{
				if ($wherestuff =~ /\S/)
				{
					#TREAT WHERE-STUFF AS LIST OF VALUES (FROM SQL TEXT)
					#FOR FIELDS LISTED IN WHERE LIST.

					@vfieldvals = split($myasdelim,$wherestuff,-1);
					$vfieldvals[0] = ''  if ($#vfieldvals < 0);
					$wherestuff = '';
					for (0..$#wherelist)
					{
						$wherestuff .= $myjdelim  if ($_ > 0);
						$wherestuff .= $wherelist[$_] . '=' . $vfieldvals[$_];
					}
					$StuffEnterred = 2;
				}
				else
				{
					&inputscr(1);  #PROMPT FOR WHERE-STUFF.
				}
				unless ($StuffEnterred)
				{
					$/ = $slash;
					return (0);
				}
				$myupdate .= ' where ';
			}
			else
			{
				$DIALOG2->configure(
						-text => "No WHERE clause specified\nUPDATE ENTIRE TABLE?");
				my ($usrres) = $DIALOG2->Show();

				if ($usrres ne $OK)
				{
					$/ = $slash;
					return (0);
				}
			}
			for ($i=0;$i<=$#fieldvals;$i++)
			{
				$fieldvals[$i] =~ s/\x02/$myjdelim/g;
#				$fieldvals[$i] =~ s/\'//g
#						if (substr($fieldvals[$i],0,1) eq '\''); 
#				$fieldvals[$i] =~ s/\"//g
#						if (substr($fieldvals[$i],0,1) eq '"');
				$fieldvals[$i] =~ s/^([\'\"])(.*)\1$/$2/;
				$lensH{$orderlist[$i]} = 0  if ($typeH[$orderlist[$i]] == 9);   #SOME DBS, NAMELY PostgreSQL DON'T HAVE CORRECT VALUE HERE (USUALLY TRUNCATE INCORRECTLY TO 4).
				if ($lensH{$orderlist[$i]} && length($fieldvals[$i]) > $lensH{$orderlist[$i]})
				{
					$fieldvals[$i] = substr($fieldvals[$i],0,$lensH{$orderlist[$i]});
					&show_err(
							" w: TRUNCATED8 \"".$fieldvals[$i]."\" (field# ".($i+1)." > $lensH{$orderlist[$i]} chars)!\n");
				}
			}
####			$#fieldvals = $#orderlist  if ($#fieldvals < $#orderlist);  #FILL W/UNDEFs IF THERE WEREN'T ENOUGH VALUES!
			my $fieldcnt = scalar(@fieldvals);
			if ($wherestuff =~ /\S/)
			{
				@wherebits = split($myasdelim,$wherestuff,-1);
				$wherebits[0] = ''  if ($#wherebits < 0);
				for ($i=0;$i<=$#wherebits;$i++)
				{
					$wherebits =~ s/\x02/$myajdelim/g;
					($wherevars,$wherevals) = split(/=/,$wherebits[$i]);
					if ($ops[$i])
					{
						$wherevals =~ s/\\([\%\_])/$1/g;
						#$myupdate .= $wherevars . $ops[$i] . ' :' . $bindcnt;
						if ($ops[$i] eq ' is' || $ops[$i] eq ' is not')
						{
							$myupdate .= $wherevars . $ops[$i] . ' NULL';
						}
						elsif ($ops[$i] eq ' in')
						{
							if ($wherevals =~ /^\s*\(.*\)\s*$/)
							{
								$myupdate .= $wherevars . $ops[$i] . ' ' . $wherevals;
							}
							else
							{
								$myupdate .= $wherevars . $ops[$i] . ' ('.$wherevals.') ';
							}
						}
						else
						{
							#my @isNumeric = DBI::looks_like_number($wherevals);
							if ($StuffEnterred == 2 && $wherevals !~ /^([\'\"]).*\1$/
									&& $wherevals =~ /^[A-Z_]/io)
							{
								$myupdate .= $wherevars . $ops[$i] . ' ' . $wherevals;
							}
							else
							{
								++$bindcnt;
								$myupdate .= $wherevars . $ops[$i] . ' ?';
								$wherevals .= '%'  if ($ops[$i] =~ /like/ && $wherevals !~ /[\%\_]/);
								push (@fieldvals,$wherevals);
								push (@mytypes, $typesH{$wherevars});
								push (@mylens, $lensH{$wherevars});
							}
						}
					}
					elsif ($wherevals =~ /[^\\][\%\_]/)
					{
						#my @isNumeric = DBI::looks_like_number($wherevals);
						if ($StuffEnterred == 2 && $wherevals !~ /^([\'\"]).*\1$/
								&& $wherevals =~ /^[A-Z_]/io)
						{
							$myupdate .= $wherevars . ' like ' . $wherevals;
						}
						else
						{
							++$bindcnt;
							$myupdate .= $wherevars . ' like ?';
							push (@fieldvals,$wherevals);
							push (@mytypes, $typesH{$wherevars});
							push (@mylens, $lensH{$wherevars});
						}
					}
					else
					{
						$wherevals =~ s/\\([\%\_])/$1/g;
						#my @isNumeric = DBI::looks_like_number($wherevals);
						if (!length($wherevals))
						{
							$myupdate .= $wherevars . ' is NULL';
						}
						elsif ($StuffEnterred == 2 && $wherevals !~ /^([\'\"]).*\1$/
								&& $wherevals =~ /^[A-Z_]/io)
						{
							$myupdate .= $wherevars . ' = ' . $wherevals;
						}
						else
						{
							++$bindcnt;
							$myupdate .= $wherevars . ' = ?';
$wherevals =~ s/^([\'\"])(.*)\1$/$2/;
							push (@fieldvals,$wherevals);
							push (@mytypes, $typesH{$wherevars});
							push (@mylens, $lensH{$wherevars});
						}
					}
					$myupdate .= $relops[$i] || (($myajdelim =~ /^\|\|?$/) ? ' or ' : ' and ')  if ($i < $#wherebits);
				}
			}
			my $myPHupdate = $myupdate;
			$statusText->insert('end',"..DOING: $myupdate\n");

			# @fieldvals, @mytypes, @mylens HAVE AN ENTRY FOR EACH NON-PREBOUND FIELD AND WHERECLAUSE PLACEHOLDER.
			for ($i=0;$i<=$bindcnt;$i++)
			{
				unless ($preboundHash{$i})
				{
					if (defined $fieldvals[$i])
					{
						$fieldvals[$i] =~ s/^([\'\"])(.*)\1$/$2/;
						$fieldvals[$i] =~ s/\'/\'\'/g;
						##$myupdate =~ s/\?/\'$fieldvals[$i]\'/;  #CHGD TO NEXT 8: 20060427 TO PREVENT ERROR!
#							if ($dbtype eq 'Sybase' && $fieldvals[$i] =~ /^((?:\'\')?)[\d\.\+\-]+\1$/)
						if ($fieldvals[$i] eq '' && $i < $fieldcnt)  #FIELDVALS IS A FIELD, NOT A WHERE-ELEMENT.
						{
							$myupdate =~ s/\?/NULL/;
						}
						elsif (($mytypes[$i] >= 2 && $mytypes[$i] <= 8) || $mytypes[$i] == 1700 || $mytypes[$i] == -5 || $mytypes[$i] == -6)
						{
							$myupdate =~ s/\?/$fieldvals[$i]/;
						}
						else
						{
							$myupdate =~ s/\?/\'$fieldvals[$i]\'/;
						}
					}
					else   #SHOULDN'T HAPPEN
					{
						$myupdate =~ s/\?/NULL/s;
					}
				}
			}
			if ($noplaceholders)
			{
				$res = $dB->do($myupdate) || $statusText->insert('end',
						" UPDATE ERROR: ".$dB->err.':'.$dB->errstr);
				unless ($dB->err)  #SYBASE/TDS ALWAYS SEEMS TO RETURN -1!
				{
					$res = '1 or more'  if ($res < 0);
				}
			}
			else
			{
				$res = $dB->do($myPHupdate,{},@fieldvals) || $statusText->insert('end',
						" UPDATE ERROR: ".$dB->err.':'.$dB->errstr);
			}
			$res = 'No'  if (!defined($res) || !$res || $res eq 'OK' || $res eq '0E0');
#2			$statusText->insert('end',".......DID: update $mytable with (".join(',',@fieldvals)."), ($res records updated).\n");
#2			if ($noplaceholders)
#2			{
				$statusText->insert('end',".......DID: $myupdate ($res records updated).\n");
#2			}
#2			else
#2			{
#2				$statusText->insert('end',".......DID: update $mytable with (".join(',',@fieldvals)."), ($res records updated).\n");
#2			}
			$statusText->see('end');
		}
		else   #INPUT WILL BE FROM A FILE.
		{
			my (@batchwhere, @mytypes1, @mylens1, @mytypes2, @mylens2);
my @fnvals = split($myasdelim,$valuestuff,-1);
			$xls = undef;
			$xlssheet = undef;
			my ($mysdelim,$myjdelim) = &getdelims(0);

			unless ($#ordbyList >= 0 || $#wherelist >= 0 || $wherestuff =~ /\S/)
			{
				$DIALOG2->configure(
						-text => "No WHERE fields specified\nUPDATE ENTIRE TABLE?");
				my ($usrres) = $DIALOG2->Show();

				if ($usrres ne $OK)
				{
					$/ = $slash;
					close (INFILE);
					return (0);
				}
			}

			#OPEN UP THE INPUT SOURCE FILE.

			if ($myfile =~ /\.xls/i)
			{
				if ($noexcelin)
				{
					&show_err("\"$myfile\" is an Excel spreadsheet and \"Spreadsheet::ParseExcel::Simple\" module not loaded!");
					return 0;
				}
				$xls = Spreadsheet::ParseExcel::Simple->read($myfile);
				unless ($xls)
				{
					&show_err(" Could not open \"$myfile\" as Excel spreadsheet ($@)!");
					return 0;
				}
				my @sheets = $xls->sheets;
				$xlssheet = $sheets[0];
				unless ($xlssheet)
				{
					&show_err(" Could not open 1st sheet of \"$myfile\" as Excel spreadsheet ($@)!");
					return 0;
				}
			}
			else
			{
				if (open(INFILE,"<$myfile"))
				{
					binmode INFILE;
				}
				else
				{
					&show_err("..Couldn't open flatfile \"$myfile\" for input ($?)!\n");
					return 0;
				}
			}
			
			#SET UP INDEX ARRAYS FOR FIELD ORDERING.
			#ORDERLIST REFLECTS EACH FIELD IN THE FILE AND THEIR ORDER IN THE RECORDS.
			#ORDBYLIST REFLECTS EACH FIELD TO BE USED IN THE "WHERE" CLAUSE RATHER THAN UPDATED.

			my @myfieldorder;
			for ($i=0;$i<=$#fields;$i++)
			{
				for ($j=0;$j<=$#orderlist;$j++)
				{
					next  if ($orderlist[$j] eq '---filler---');
					if ($fields[$i] eq $orderlist[$j])
					{
						$myfieldorder[$j] = $i;
					}
				}
			}
			my (@mytitles, @mytypes, @mylens);
			for ($j=0;$j<=$#orderlist;$j++)
			{
				next  if ($orderlist[$j] eq '---filler---');   #???
				push (@mytitles, $titles[$myfieldorder[$j]]);
				push (@mytypes, $types[$myfieldorder[$j]]);
				push (@mylens, $lens[$myfieldorder[$j]]);
			}
			$setstuff = '';
			$item = 1;
			my ($setcnt) = 0;
			my $nextArg = 0;            #CURRENT POSITION IN FIELD LIST.
			for ($i=0;$i<=$#orderlist;$i++)
			{
				next  if ($orderlist[$i] eq '---filler---');
				$found = 0;
				for ($j=0;$j<=$#ordbyList;$j++)
				{
					if ($orderlist[$i] eq $ordbyList[$j])
					{
						$found = 1;
						$ordbyList[$j] = undef;
#						push (@batchwhere, $i);
						last;
					}
				}
				if ($found)  #FIELD ALSO IN ORDERBYLIST, WILL GO IN "WHERE" LIST.
				{
					$wherestuff .= ' and ' if ($wherestuff =~ /\S/);
					$wherestuff .= $orderlist[$i] . '= ';
#					$wherestuff .= '?';
#					push(@myorder2,$i);
					if (defined($fnvals[$myfieldorder[$i]]) && length($fnvals[$myfieldorder[$i]]) > 0)
					{
						my $fnval = $fnvals[$myfieldorder[$i]];
						while ($fnval =~ s/(.+)\:(\d+)/$1\?/)
						{
							my ($one, $two) = ($1, $2);
							if ($one =~ /([\'\"])$/)
							{
								my $quotechar = $1;
								push (@mytypes2, 1);   #A STRING TYPE.
								push (@mylens2, 32767);
								$fnval =~ s/$quotechar\?$quotechar/\?/; #  unless ($noplaceholders);   #MUST CONVERT '?' TO ? FOR BINDS!
							}
							else
							{
								push (@mytypes2, 2);   #A NUMERIC TYPE.
								push (@mylens2, 255);
							}
							push (@myorder2, $two);
						}
						$wherestuff .= $fnval;
					}
					else
					{
						$wherestuff .= '?';
						push (@mytypes2, $mytypes[$nextArg]);
						push (@mylens2, $mylens[$nextArg]);
						push (@myorder2, $i);
					}
				}
				else         #FIELD ONLY IN ORDER LIST, WILL GO IN UPDATE LIST.
				{
					$setstuff .= ',' if ($setstuff =~ /\S/);
					$setstuff .= $orderlist[$i] . '=';
#					$setstuff .= '?';
#					push(@myorder1,$i);
					if (defined($fnvals[$myfieldorder[$i]]) && length($fnvals[$myfieldorder[$i]]) > 0)
					{
						my $fnval = $fnvals[$myfieldorder[$i]];
						while ($fnval =~ s/(.+)\:(\d+)/$1\?/)
						{
							my ($one, $two) = ($1, $2);
							if ($one =~ /([\'\"])$/)
							{
								my $quotechar = $1;
								push (@mytypes1, 1);   #A STRING TYPE.
								push (@mylens1, 32767);
								$fnval =~ s/$quotechar\?$quotechar/\?/; #  unless ($noplaceholders);   #MUST CONVERT '?' TO ? FOR BINDS!
							}
							else
							{
								push (@mytypes1, 2);   #A NUMERIC TYPE.
								push (@mylens1, 255);
							}
							push (@myorder1, $two);
						}
						$setstuff .= $fnval;
					}
					else
					{
						$setstuff .= '?';
						push (@mytypes1, $mytypes[$nextArg]);
						push (@mylens1, $mylens[$nextArg]);
						push (@myorder1, $i);
					}
					++$setcnt;
				}
				++$nextArg;
			}
#print "-update- batchwhere=".join('|',@batchwhere)."=\n";
			my @colorder = (@myorder1,@myorder2);
#print "-update- myorder1=".join('|',@myorder1)."= myorder2=".join('|',@myorder2)."=\n";

			my @timestuff = localtime(time);
			my ($today);
			$today = '0'  if ($timestuff[4] < 9);
			$today .= $timestuff[4] + 1;
			$today .= '/';
			$today .= '0'  if ($timestuff[3] < 10);
			$today .= $timestuff[3];
			$today .= '/';
			$today .= $timestuff[5] + 1900;

			my $batchcodePre = <<END_CODE;
#!/usr/bin/perl

### THIS CODE AUTO-GENERATED $today BY SQL-PERL PLUS v. $vsn TO BACH-UPDATE 
###    DATA INTO TABLE "$mytable", 
###    OF "$dbtype" DATABASE "$dbname".

unless (\$ARGV[0] && \$ARGV[0] !~ /\-\-/i)
{
	print <<END_MSG;
..usage: \$0 <textfile> 
..updates data from <textfile> into table \"$mytable\" 
of \"$dbtype\" database \"$dbname\".
END_MSG
	exit (0);
}

use DBI;

open (INFILE, "<\$ARGV[0]") || die "Could not open input file (\$ARGV[0])!";
binmode INFILE;
my \$dB=DBI->connect('$connectstr','$dbuser','$dbpswd', {$attb}) 
		|| die 'Could not connect('.DBI->err.':'.DBI->errstr.')!';
\$dB->{AutoCommit} = $dB->{AutoCommit};
END_CODE
			my $batchcode = ($noplaceholders) 
					? "my \$updstr = \"" : "my \$updcsr = \$dB->prepare(\"";
			$myupdate = "update $mytable set $setstuff ";

			if ($wherestuff =~ /\S/ || $#wherelist >= 0)
			{
				$myupdate .= ' where ' . $wherestuff;
				$addand = 1;
			}
			if ($#wherelist >= 0)
			{
				$wherestuff = $sqlText->get('0.0','end');
				$wherestuff =~ s/\\h\=.*$//g;
				if ($wherestuff =~ /\S/)
				{
					$StuffEnterred = 2;
				}
				else
				{
					&inputscr(1);  #SETS WHERESTUFF.
				}
				if ($StuffEnterred)
				{
					$myupdate .= (($myajdelim =~ /^\|\|?$/) ? ' and (' : ' and ') if ($addand);
					@wherebits = split($myasdelim,$wherestuff,-1);
					$wherebits[0] = ''  if ($#wherebits < 0);
					my $isNumeric;
					for ($i=0;$i<=$#wherebits;$i++)
					{
						$wherebits =~ s/\x02/$myajdelim/g;
						($wherevars,$wherevals) = split(/\=/,$wherebits[$i]);
						$isNumeric = ($typesH{$wherevars} >= 2 && $typesH{$wherevars} <= 8) 
								|| $typesH{$wherevars} == 1700 || $typesH{$wherevars} == -5
								|| $typesH{$wherevars} == -6;
FOUNDINORDER:						if ($ops[$i])
						{
							#$myupdate .= $wherevars . $ops[$i] . ' :' . $item;
							if ($ops[$i] eq ' is' || $ops[$i] eq ' is not')
							{
								$myupdate .= $wherevars . $ops[$i] . ' NULL';
							}
							elsif ($ops[$i] eq ' in')
							{
								if ($wherevals =~ /^\s*\(.*\)\s*$/)
								{
									$myupdate .= $wherevars . $ops[$i] . ' ' . $wherevals;
								}
								else
								{
									$myupdate .= $wherevars . $ops[$i] . ' ('.$wherevals.') ';
								}
							}
							elsif ($isNumeric || $StuffEnterred == 2 || ($wherevals =~ /^([\'\"]).*\1$/))
							{    #DO NOT ADD SURROUNDING QUOTES.
								$myupdate .= $wherevars . $ops[$i] . ' ' . $wherevals;
								$wherevals =~ s/([\'\"])$/\%\1/  if ($ops[$i] =~ /like/ && $wherevals !~ /[\%\_]/);
								++$item;
#print "-???111111111111- update2: mylens=".join('|',@mylens)."= WV=$wherevars=\n";
							}
							else   #VALUE NEEDS QUOTING.
							{
								$wherevals .= '%'  if ($ops[$i] =~ /like/ && $wherevals !~ /[\%\_]/);
								$myupdate .= $wherevars . $ops[$i] . " '$wherevals'";
								++$item;
#print "-???222222222222- update3: mylens=".join('|',@mylens)."= WV=$wherevars=\n";
							}
						}
						elsif ($wherevals =~ /[^\\][\%\_]/)
						{
							if ($isNumeric || $StuffEnterred == 2 || ($wherevals =~ /^([\'\"]).*\1$/))
							{
								$myupdate .= $wherevars . ' like ' . $wherevals;
							}
							else
							{
								$myupdate .= $wherevars . " like '$wherevals'";
							}
							++$item;
#print "-???3333333333333333- update4: mylens=".join('|',@mylens)."= WV=$wherevars=\n";
						}
						else
						{
							$wherevals =~ s/\\([\%\_])/$1/g;
							if ($isNumeric || $StuffEnterred == 2 || ($wherevals =~ /^([\'\"]).*\1$/))
							{
								$myupdate .= $wherevars . ' = ' . $wherevals;
							}
							else
							{
								$myupdate .= $wherevars . " = '$wherevals'";
							}
							++$item;
						}
						#$myupdate .= ' and '  if ($i < $#wherebits);
						$myupdate .= $relops[$i]|| ' and '  if ($i < $#wherebits);
					}
					$myupdate .= ')'  if ($addand && $myajdelim =~ /^\|\|?$/);
				}
			}
			$statusText->insert('end',"..DOING: $myupdate\n");
			$statusText->see('end');
			$batchcode .= $myupdate;
			if ($noplaceholders)
			{
				$batchcode .= "\";\n";
				$batchcode .= "my \$updsql = \$updstr;\n";
			}
			else
			{
				$batchcode .= "\") \n";
				$batchcode .= <<END_CODE;
			|| die ('Could not prepare ('.\$dB->err.':'.\$dB->errstr.")!\\n");
END_CODE
			}

			my $hexvals = unpack('H*',$myrjdelim);
			$hexvals =~ s/([0-9a-f][0-9a-f])/\\x$1/gs;
			$batchcode .= "my \@types = (".join(',', @mytypes1, @mytypes2).");\n";
			$batchcode .= "my \@lens = (".join(',', @mylens1, @mylens2).");\n";
			$batchcode .= "my \@colorder = (".join(',', @myorder1, @myorder2).");\n";
			$batchcode .= "my (\@infieldvals, \@fieldvals);\n";
			$batchcode .= <<END_CODE;
my \$cnt = 0;           #NUMBER OF RECORDS READ FROM INPUT FILE.
my \$reccnt = 0;        #ZERO-BASED NUMBER OF RECORD JUST UPDATED.
my \$errwarncnt = '0';  #SUM OF ERRORS AND WARNINGS.
my \$res;               #RESULT OF DBI->EXECUTE.
END_CODE
			unless ($xlssheet)
			{
				$batchcode .= <<END_CODE;
\$/ = "$hexvals";
END_CODE
			}
			if (!$xlssheet && $mymyfmt =~ /\S/)
			{
				$batchcode .= "my \@leftjust = ('<InsertLeftJustValueHere!>');\n";
			}
			$batchcode .= <<END_CODE;

print STDERR "..updating records, please wait..\\n";
END_CODE
			if ($headers)
			{
				if ($xlssheet)
				{
					$batchcode .= <<END_CODE;
\$xlssheet->next_row  if (\$xlssheet->has_data);
\$cnt++;
END_CODE
				}
				else
				{
					$batchcode .= <<END_CODE;
<INFILE>;     #SKIP FIRST RECORD SINCE IT IS A HEADER RECORD.
\$cnt++;
END_CODE
				}
			}
			if ($xlssheet)
			{
				$batchcode .= <<END_CODE;

my \$rowhasdata;
while (\$xlssheet->has_data)
{
	\@infieldvals = \$xlssheet->next_row;
	++\$cnt;
	\$rowhasdata = 0;
	for (my \$i=0;\$i<=\$#infieldvals;\$i++)
	{
		if (length(\$infieldvals[\$i]) > 0)
		{
			\$rowhasdata = 1;
			last;
		}
	}
	next  unless (\$rowhasdata);

	\@fieldvals = ();
	for (my \$i=0;\$i<=\$#colorder;\$i++)
	{
		if (\$types[\$i] >= 2 && \$types[\$i] <= 8)
		{
			\$infieldvals[\$colorder[\$i]] =~ s/\-\-/\-/;  #FIX PARSEEXCEL BUG!
		}
		if (length(\$infieldvals[\$colorder[\$i]]) > \$lens[\$i])
		{
			warn (" w:(rec#\$cnt) TRUNCATED \\"".\$infieldvals[\$colorder[\$i]]."\\" (field# ".(\$i+1)." > \$lens[\$i] chars)!");
			\$infieldvals[\$colorder[\$i]] = substr(\$infieldvals[\$colorder[\$i]],0,\$lens[\$i]);
			++\$errwarncnt;
		}
END_CODE
				if ($noplaceholders)
				{
						$batchcode .= <<END_CODE;
		if (\$infieldvals[\$colorder[\$i]] eq '')
		{
			\$updsql =~ s/\\?/NULL/;
			push (\@fieldvals, 'NULL');
		}
		elsif ((\$types[\$i] >= 2 
				&& \$types[\$i] <= 8) 
				|| \$types[\$i] == 1700
				|| \$types[\$i] == -5
				|| \$types[\$i] == -6)
		{
			\$infieldvals[\$colorder[\$i]] =~ s/^\\'\\'\?(.*)\\'\\'\?\$/\\'\$1\\'/;
			\$updsql =~ s/\\?/\$infieldvals[\$colorder[\$i]]/;
			push (\@fieldvals, \$infieldvals[\$colorder[\$i]]);
		}
		else
		{
			\$updsql =~ s/\\?/\'\$infieldvals[\$colorder[\$i]]\'/;
			push (\@fieldvals, "\'\$infieldvals[\$colorder[\$i]]\'");
		}
END_CODE
				}
				else
				{
					$batchcode .= "		push (\@fieldvals, \$infieldvals[\$colorder[\$i]]);\n";
				}
				$batchcode .= <<END_CODE;
	}
END_CODE
			}
			else
			{
				$batchcode .= <<END_CODE;
while (<INFILE>)     #READ RECORDS FROM INPUT FILE.
{
	++\$cnt;
print "--- cnt=\$cnt= ab=\$abortit= line=\$_=\\n";  #DEBUG!
	\@infieldvals = ();
	\@fieldvals = ();
END_CODE
				$batchcode .= "	next  if (/^$ffchar/);\n"  if ($ffchar && $headers);
				if ($mymyfmt =~ /\S/)
				{
					$batchcode .= "	next  if (/^(?:$mysdelim|\\s)+\$/);\n"  if ($headers && $myjdelim =~ /\S/);    #YES, THIS NEEDS TO BE mySdelim TO ESCAPE SPECIAL CHARS!
					@fmtblks = ($mymyfmt =~ /(.*?\@(?:\d+[\<\|\>])?)/g);
					@fmtlens = ();
					@start = ();
					@fmtjust = ();
					$start = 0;
					for (my $i=0;$i<=$#fmtblks;$i++)
					{
						if ($fmtblks[$i] =~ /(.*)\@(\d+)(.)/)
						{
							$fmtblk = length($1);
							$fmtlens[$i] = $2;
							++$fmtlens[$i];
							$start += $fmtblk;
							$start[$i] = $start;
							$start += $fmtlens[$i];
							$fmtjust[$i] = $3;
						}
						elsif ($fmtblks[$i] =~ /(.*)\@/)
						{
							$fmtblk = length($1);
							$fmtlens[$i] = 1;
							$start += $fmtblk;
							$start[$i] = $start;
							$start++;
							$fmtjust[$i] = '>';
						}
						#CHGD. TO NEXT 2 20030620 TO PREVENT GARBAGE IN HEADER 
						#COMMENT FIELDS IN GENERATED SQLTEMP.PL
#						$batchcode .= "\n	#Field: \"" 
#								. ($fmtheaders[$i]  || $orderlist[$i] || "--UNUSED--");
						$batchcode .= "\n	#Field: \"" 
								. ($orderlist[$i] || "--UNUSED--");
						$batchcode .= "\".\n";
						$batchcode .= "	\$x = substr(\$_,$start[$i],$fmtlens[$i]);\n";
###########						$batchcode .= "	\$x =~ s/^\\s+//;\n"  if ($types[$i] != 1 && $fmtjust[$i] ne '<');
###########						$batchcode .= "	\$x =~ s/\\s+\$//;\n"  if ($types[$i] != 1);
#$batchcode .= "###### TYPE=$types[$i]= lens=$lens[$i]= i=$i= field=$orderlist[$i]=\n";
						$batchcode .= "	push (\@infieldvals, \$x);\n";
					}
					if (!$xlssheet)
					{
						my $bc;
						for (my $i=0;$i<=$#fmtblks;$i++)
						{
							$bc .= ($fmtjust[$i] eq '<' || ($mytypes[$i] >= 2 && $mytypes[$i] <= 8) 
							|| $mytypes[$i] == 1700 || $mytypes[$i] == -5 
							|| $mytypes[$i] == -6) ? '1,' : '0,';
						}
						chop ($bc);
						$batchcode =~ s/\'\<InsertLeftJustValueHere\!\>\'/$bc/;
					}
					$batchcode .= <<END_CODE;
	for (my \$i=0;\$i<=\$#colorder;\$i++)
	{
		if (\$types[\$i] != 1)
		{
			\$infieldvals[\$colorder[\$i]] =~ s/^\\s+//  if (\$leftjust[\$colorder[\$i]]);
			\$infieldvals[\$colorder[\$i]] =~ s/\\s+\$//;
		}
END_CODE
					if ($noplaceholders)
					{
						$batchcode .= <<END_CODE;
		if (\$infieldvals[\$colorder[\$i]] eq '')
		{
			\$updsql =~ s/\\?/NULL/;
			push (\@fieldvals, 'NULL');
		}
		elsif ((\$types[\$i] >= 2 
				&& \$types[\$i] <= 8) 
				|| \$types[\$i] == 1700
				|| \$types[\$i] == -5
				|| \$types[\$i] == -6)
		{
			\$infieldvals[\$colorder[\$i]] =~ s/^\\'\\'\?(.*)\\'\\'\?\$/\\'\$1\\'/;
			\$updsql =~ s/\\?/\$infieldvals[\$colorder[\$i]]/;
			push (\@fieldvals, \$infieldvals[\$colorder[\$i]]);
		}
		else
		{
			\$updsql =~ s/\\?/\'\$infieldvals[\$colorder[\$i]]\'/;
			push (\@fieldvals, "\'\$infieldvals[\$colorder[\$i]]\'");
		}
END_CODE
					}
					else
					{
						$batchcode .= "		push (\@fieldvals, \$infieldvals[\$colorder[\$i]]);\n";
					}
					$batchcode .= <<END_CODE;
	}
END_CODE
				}
				elsif ($myjdelim =~ /^\"(\S+)\"$/)  #20030811: HANDLE CSV FILES!
				{
					my $mysdelimchar = $1;
					$batchcode .= <<END_CODE;
	chomp;
	next  unless (\$_);   #SKIP COMPLETELY BLANK LINES.
	s/\\"\\"/\\x02\\^1jSpR1tE\\x02/gs;   #PROTECT QUOTE PAIRS (QUOTES ARE ESCAPED BY PARING)
	s/\\"([^\\"]*?)\\"/
			my (\$str) = \$1;
			\$str =~ s|\Q$mysdelimchar\E|\\x02\\^2jSpR1tE\\x02|gs;   #PROTECT COMMAS IN QUOTES.
			"\\"\$str\\""/egs;

	\@infieldvals = split(/\\$mysdelimchar/,\$_,-1);
	for (my \$i=0;\$i<=\$#colorder;\$i++)
	{
		\$infieldvals[\$colorder[\$i]] =~ s/\\"//gs;   #REMOVE THE BOUNDING QUOTES
		\$infieldvals[\$colorder[\$i]] =~ s/\\x02\\^2jSpR1tE\\x02/\\$mysdelimchar/gs;  #UNPROTECT COMMAS.
		\$infieldvals[\$colorder[\$i]] =~ s/\\x02\\^1jSpR1tE\\x02/\\"/gs;  #UNPROTECT QUOTES.
		if (length(\$infieldvals[\$colorder[\$i]]) > \$lens[\$i])
		{
			warn (" w:(rec#\$cnt) TRUNCATED \\"".\$infieldvals[\$colorder[\$i]]."\\" (field# ".(\$i+1)." > \$lens[\$i] chars)!");
			\$infieldvals[\$colorder[\$i]] = substr(\$infieldvals[\$colorder[\$i]],0,\$lens[\$i]);
			++\$errwarncnt;
		}
END_CODE
					if ($noplaceholders)
					{
						$batchcode .= <<END_CODE;
			if (\$infieldvals[\$colorder[\$i]] eq '')
			{
				\$updsql =~ s/\\?/NULL/;
				push (\@fieldvals, 'NULL');
			}
			elsif ((\$types[\$i] >= 2 
					&& \$types[\$i] <= 8) 
					|| \$types[\$i] == 1700
					|| \$types[\$i] == -5
					|| \$types[\$i] == -6)
			{
				\$infieldvals[\$colorder[\$i]] =~ s/^\\'\\'\?(.*)\\'\\'\?\$/\\'\$1\\'/;
				\$updsql =~ s/\\?/\$infieldvals[\$colorder[\$i]]/;
				push (\@fieldvals, \$infieldvals[\$colorder[\$i]]);
			}
			else
			{
				\$updsql =~ s/\\?/\'\$infieldvals[\$colorder[\$i]]\'/;
				push (\@fieldvals, "\'\$infieldvals[\$colorder[\$i]]\'");
			}
END_CODE
					}
					else
					{
						$batchcode .= "			push (\@fieldvals, \$infieldvals[\$colorder[\$i]]);\n";
					}
					$batchcode .= <<END_CODE;
	}
END_CODE
				}
				else
				{
					$batchcode .= <<END_CODE;
	chomp;
	next  unless (\$_);   #SKIP COMPLETELY BLANK LINES.
	\@infieldvals = split(/$mysdelim/,\$_,-1);
	for (my \$i=0;\$i<=\$#colorder;\$i++)
	{
		if (length(\$infieldvals[\$colorder[\$i]]) > \$lens[\$i])
		{
			warn (" w:(rec#\$cnt) TRUNCATED \\"".\$infieldvals[\$colorder[\$i]]."\\" (field# ".(\$i+1)." > \$lens[\$i] chars)!");
			\$infieldvals[\$colorder[\$i]] = substr(\$infieldvals[\$colorder[\$i]],0,\$lens[\$i]);
			++\$errwarncnt;
		}
END_CODE
					if ($noplaceholders)
					{
						$batchcode .= <<END_CODE;
		if (\$infieldvals[\$colorder[\$i]] eq '')
		{
			\$updsql =~ s/\\?/NULL/;
			push (\@fieldvals, 'NULL');
		}
		elsif ((\$types[\$i] >= 2 
				&& \$types[\$i] <= 8) 
				|| \$types[\$i] == 1700
				|| \$types[\$i] == -5
				|| \$types[\$i] == -6)
		{
			\$infieldvals[\$colorder[\$i]] =~ s/^\\'\\'\?(.*)\\'\\'\?\$/\\'\$1\\'/;
			\$updsql =~ s/\\?/\$infieldvals[\$colorder[\$i]]/;
			push (\@fieldvals, \$infieldvals[\$colorder[\$i]]);
		}
		else
		{
			\$updsql =~ s/\\?/\'\$infieldvals[\$colorder[\$i]]\'/;
			push (\@fieldvals, "\'\$infieldvals[\$colorder[\$i]]\'");
		}
END_CODE
					}
					else
					{
						$batchcode .= "		push (\@fieldvals, \$infieldvals[\$colorder[\$i]]);\n";
					}
					$batchcode .= <<END_CODE;
	}
END_CODE
#1	1 while (\$updsql =~ s/\\:(\\d+)/\$infieldvals[\$1]/);
				}
			}
			if ($noplaceholders)
			{
				$batchcode .= <<END_CODE;
	\$res = 0;
	if (\$updcsr = \$dB->prepare(\$updsql))
	{
		\$res = \$updcsr->execute();
		if (\$res)
		{
			\$updcsr->finish();
		}
		else
		{
			warn ('Could not execute record# '.(\$reccnt+1).' ('.\$dB->err.':'.\$dB->errstr.')!');
			++\$errwarncnt;
		}
	}
	else
	{
		warn ('Could not prepare record# '.(\$reccnt+1).' ('.\$dB->err.':'.\$dB->errstr.')!');
		++\$errwarncnt;
	}
	\$updsql = \$updstr;
END_CODE
			}
			else
			{
				$batchcode .= <<END_CODE;
	\$res = \$updcsr->execute(\@fieldvals) 
			|| (warn ('Could not execute record# '.(\$reccnt+1).' ('.\$dB->err.':'.\$dB->errstr.')!') && ++\$errwarncnt);
	\$updcsr->finish();
END_CODE
			}
			$batchcode .= "\t++\$reccnt  if (\$res >= 1);\n";
			$batchcode .= "\t\$dB->commit()  unless (\$dB->{AutoCommit} || \$reccnt % 20);\n";
#			$reccount += $commitcnt;
#			$statusText->insert('end',".......updated $reccount records in $mytable, $errorsfound errors/warnings.\n");
#			$statusText->see('end');
			$batchcode .= <<END_CODE;
}
\$updcsr->finish();
\$dB->commit()  unless (\$dB->{AutoCommit});
close INFILE;
\$dB->disconnect();
print STDERR "..done: \$cnt lines read, ".(\$reccnt)." records updated to \\\"$mytable\\\" from file: \\\"\$ARGV[0]\\\"; \$errwarncnt errors/warnings!\\n";
exit (0);

END_CODE
			$batchcodePre .= $batchcode;
			$batchcode =~ s/exit \(0\)\;/\#exit \(0\)\;/gso;
			$batchcode =~ s/\+\+\$cnt\;/\+\+\$cnt\;\n\tlast  if \(\$abortit\)\;/so;
			$batchcode =~ s/warn \(/\&show_err\(/gso;
			$batchcode =~ s/\t\+\+\$reccnt  if \(\$res \>\= 1\)\;/
\tif \(\$res \>\= 1\)
\t\{
\t\t\$statusText\-\>insert\(\'end\'\,\"\.\.\.\.\.\.\.DID\(\$reccnt\)\: update \$mytable with \(\"\.join(\'\,\'\,\@fieldvals\)\.\"\)\.\\n\"\)\;
\t\t\+\+\$reccnt\;
\t\t\+\+\$commitcnt\;
\t\}
/so;
			$batchcode =~ s/\t\$dB\-\>commit\(\)  unless \(\$dB\-\>\{AutoCommit\} \|\| \$reccnt \% 20\)\;/
\t\$statusText\-\>see\(\'end\'\)\;
\tunless \(\$reccnt \% 20\)
\t\{
\t\tif \t(\$newerrorsfound \|\| \(\$usrres ne \$OkAll \&\& \$nocommit \=\= 1\)\)
\t\t\{
\t\t\t\$usrres \= \$DIALOG3\-\>Show\(\'$showgrabopt\'\)\;
\t\t\t\$newerrorsfound \= 0\;
\t\t\}
\t\telse
\t\t\{
\t\t\t\$usrres \= \$OkAll\;
\t\t\}
\t\tif \(\$usrres eq \$Cancel\)
\t\t\{
\t\t\tif \(\$nocommit \< 2\)
\t\t\t\{
\t\t\t\t\&dorollback\(\)\;
\t\t\t\t\$commitcnt \= 0\;
\t\t\t\}
\t\t\tlast\;
\t\t\}
\t\t\&docommit\(\)  if \(\$nocommit \< 2\)\;
\t\t\$reccount \+\= \$commitcnt\;
\t\t\$commitcnt \= 0\;
\t}
/so;
			$batchcode =~ s/close INFILE;/close INFILE;
if \(\!\$abortit \&\& \$nocommit \< 2\)
\{
\tif \(\$commitcnt \&\& \(\$newerrorsfound \|\| \(\$usrres ne \$OkAll \&\& \$nocommit \=\= 1\)\)\)
\t\{
\t\t\$usrres \= \$DIALOG3\-\>Show\(\'$showgrabopt\'\)\;
\t\t\$newerrorsfound \= 0\;
\t\}
\telse
\t\{
\t\t\$usrres \= \$OkAll\;
\t\}
\tif \(\$usrres eq \$Cancel\)
\t\{
\t\tif \(\$nocommit \< 2\)
\t\t\{
\t\t\t\&dorollback\(\)\;
\t\t\t\$commitcnt \= 0\;
\t\t\}
\t\}
\telse
\t\{
\t\t\&docommit\(\)\;
\t\}
\}
\$reccount \+\= \$commitcnt\;
\$statusText\-\>insert\(\'end\'\,\"\.\.\.\.\.\.\.updated \$reccount records in \$mytable\, \$errorsfound errors\/warnings\.\\n\"\)\;
\$statusText\-\>see\(\'end\'\)\;
/so;
			$abortit = 0;
			$newerrorsfound = 0;
			$commitcnt = 0;
			$readcnt = 0;
			$reccount = 0;
			$commitcnt = 0;
			$usrres = '';

			open (OUTFILE2, ">sqltemp.pl");
			binmode OUTFILE2;    #20000404
			print OUTFILE2 $batchcode;
			close OUTFILE2;
			open (OUTFILE2, ">sqltemppre.pl");
			binmode OUTFILE2;    #20000404
			print OUTFILE2 $batchcodePre;
			close OUTFILE2;

			eval $batchcode;
			&show_err($@)  if ($@);
		}
	}
	$/ = $slash;
}

sub dodelete
{
	my ($i, $mydelete, $myfile);
	my ($bindcnt, @wherebits);
	my (@titles, @types, @lens, %typesH, %lensH, @mytypes, @mylens, $delcsr);

	$errorsfound = 0;
	$wherestuff = $sqlText->get('0.0','end');
	$wherestuff =~ s/\n//g;
	($mysdelim,$myjdelim) = &getdelims(0);
	my ($myasdelim, $myajdelim) = &getdelims(2);
	my (@wherelist) = $whereList->get('0','end');
	@fieldvals = ();
	if ($use eq 'sql')
	{
		$mydelete = $sqlText->get('0.0','end');
		$mydelete =~ s/;+$//;
		if ($mydelete =~ /^\s*drop|truncate/i)
		{
			$DIALOG2->configure(
					-text => "ABOUT TO DROP/TRUNCATE TABLE!\nAre you SURE?");
			my ($usrres) = $DIALOG2->Show();

			return (0)  if $usrres ne $OK;
		}
		$mydelete =~ /\btable\b\s*(\S+)/i;
		$chktable = "\U$1";
		unless ($sUperman || &chkacc("$dbname:$dbuser:$chktable",$me))
		{
			&show_err("..NOT AUTHORIZED TO ACCESS TABLE \"$chktable\"!\n");
			return (0);
		}
		unless ($mydelete =~ /\s*delete/i)
		{
			&show_err("..INVALID SQL delete command!\n");
			return (0);
		}
	}
	else
	{
		my $useTop2Limit = '';
		$useTop2Limit = 'top 1 '  if ($dbtype eq 'Sybase');
		if ($delcsr = $dB->prepare('select '.$useTop2Limit." * from $mytable", {ldap_sizelimit => 1, sprite_sizelimit => 1}))
		{	
			$delcsr->execute;
			&show_err("sql select: EXEC ERROR: ".$dB->err.':'.$dB->errstr)  if ($dB->err);
			#@lens = @{$delcsr->{PRECISION}};
			@titles = @{$delcsr->{NAME}};
			@types = @{$delcsr->{TYPE}};
			@lens = @{$delcsr->{PRECISION}};
			if ($dbtype eq 'Oracle')
			{
				my @oralens = @{$delcsr->{'ora_lengths'}};   #ORACLE-SPECIFIC.
				for (my $i=0;$i<=$#lens;$i++)
				{
					$lens[$i] ||= $oralens[$i];
				}
			}
			elsif ($dbtype eq 'mysql')
			{
				@lens = @{$delcsr->{mysql_length}};
			}
			$delcsr->finish;
			for (my $i=0;$i<=$#titles;$i++)
			{
				$typesH{$titles[$i]} = $types[$i];
				$lensH{$titles[$i]} = $lens[$i];
			}
		}
		$mydelete = "delete from $mytable";
		if ($use eq 'line')
		{
			if ($wherestuff =~ /\S/ && $#wherelist < 0)
			{
				#EMPTY WHERE-LIST - TREAT STUFF IN SQL BOX AS A COMPLETE
				#WHERE-CLAUSE.

				$mydelete .= ' where ' . $wherestuff;
				$wherestuff = '';
			}
			elsif ($#wherelist >= 0)
			{
				$mydelete .= ' where ';
				$StuffEnterred = 0;
				if ($wherestuff =~ /\S/)
				{
					#TREAT WHERE-STUFF AS LIST OF VALUES
					#FOR FIELDS LISTED IN ORDER-BY LIST.
					@fieldvals = split($myasdelim,$wherestuff,-1);
					$fieldvals[0] = ''  if ($#fieldvals < 0);
					$wherestuff = '';
					for (0..$#wherelist)
					{
						($wherevars,$wherevals) = split(/=/,$wherebits[$i]);
						$wherestuff .= $myajdelim  if ($_ > 0);
						$wherestuff .= $wherelist[$_] . '=' . $fieldvals[$_];
					}
					$StuffEnterred = 2;
				}
				else
				{
					&inputscr(1);  #PROMPT FOR WHERE-STUFF.
				}
				if ($StuffEnterred)
				{
					@wherebits = split($myasdelim,$wherestuff,-1);
					$wherebits[0] = ''  if ($#wherebits < 0);
					@fieldvals = ();
					for ($i=0;$i<=$#wherebits;$i++)
					{
						$wherebits =~ s/\x02/$myajdelim/g;
						($wherevars,$wherevals) = split(/=/,$wherebits[$i]);
						if ($ops[$i])
						{
							if ($ops[$i] eq ' is' || $ops[$i] eq ' is not')
							{
								$mydelete .= $wherevars . $ops[$i] . ' NULL';
							}
							elsif ($ops[$i] eq ' in')
							{
								if ($wherevals =~ /^\s*\(.*\)\s*$/)
								{
									$mydelete .= $wherevars . $ops[$i] . ' ' . $wherevals;
								}
								else
								{
									$mydelete .= $wherevars . $ops[$i] . ' ('.$wherevals.') ';
								}
							}
							else
							{
								++$bindcnt;
								$mydelete .= $wherevars . $ops[$i] . ' ?';
								$wherevals .= '%'  if ($ops[$i] =~ /like/ && $wherevals !~ /[\%\_]/);
								push (@fieldvals,$wherevals);
								push (@mytypes, $typesH{$wherevars});
								push (@mylens, $lensH{$wherevars});
							}
						}
						elsif ($wherevals =~ /[^\\][\%\_]/)
						{
							++$bindcnt;
							#$mydelete .= $wherevars . ' like :' . $bindcnt;
							$mydelete .= $wherevars . ' like ?';
							push (@fieldvals,$wherevals);
							push (@mytypes, $typesH{$wherevars});
							push (@mylens, $lensH{$wherevars});
						}
						else
						{
							++$bindcnt;
							#$mydelete .= $wherevars . '=:' . $bindcnt;
							$mydelete .= $wherevars . '= ?';
							push (@fieldvals,$wherevals);
							push (@mytypes, $typesH{$wherevars});
							push (@mylens, $lensH{$wherevars});
						}
						#$mydelete .= ' and '  if ($i < $#wherebits);
						$mydelete .= $relops[$i]||' and '  if ($i < $#wherebits);
					}
				}
				return (0)  if ($wherestuff le ' ');
			}
			else
			{
				$DIALOG2->configure(
						-text => "No WHERE clause specified\nDELETE ENTIRE TABLE:\n\"$mytable\"?");
				my ($usrres) = $DIALOG2->Show();

				return (0)  if $usrres ne $OK;
			}
		}
		else
		{
			&show_err("..DELETE not valid with FILE option!\n");
			return (0);
		}
	}
#	my ($delstr) = $mydelete;
#	#$delstr =~ s/:(\d+)/\'$fieldvals[$1-1]\'/g;
#	$_ = $delstr;
#	for ($i=0;$i<=$#fieldvals;$i++)
#	{
#		s/\?/\'$fieldvals[$i]\'/;
#	}
#	$DIALOG2->configure(
#			-text => "Do: \"$_\" (SURE?)");
#	my ($usrres) = $DIALOG2->Show();

#	return (0)  if $usrres ne $OK;
	$statusText->insert('end',"..DOING:  $mydelete!\n");
	$statusText->see('end');
	if ($#fieldvals >= 0)
	{
		#$delcsr = &ora_open($dB,$mydelete) || &show_err(" DELETE ERROR: ".$dB->err.':'.$dB->errstr);
		#return  unless ($delcsr);
		#$res = &ora_bind($delcsr,@fieldvals) 
		my $myPHdelete = $mydelete;
		for ($i=0;$i<=$#fieldvals;$i++)
		{
			if (defined $fieldvals[$i])
			{
				$fieldvals[$i] =~ s/\'/\'\'/g;
				$fieldvals[$i] =~ s/\?/\x02\^2jSpR1tE\x02/gs;
				##$mydelete =~ s/\?/\'$fieldvals[$i]\'/;  #CHGD TO NEXT 8: 20060427 TO PREVENT ERROR!
#					if ($dbtype eq 'Sybase' && $fieldvals[$i] =~ /^((?:\'\')?)[\d\.\+\-]+\1$/)
				if ($fieldvals[$i] eq '')
				{
					$mydelete =~  s/\?/NULL/;
				}
				elsif ($StuffEnterred == 2 || ($mytypes[$i] >= 2 && $mytypes[$i] <= 8) 
						|| $mytypes[$i] == 1700 || $mytypes[$i] == -5
						|| $mytypes[$i] == -6)
				{
					$fieldvals[$i] =~ s/^\'\'(.*)\'\'$/\'$1\'/;
					$mydelete =~ s/\?/$fieldvals[$i]/;
				}
				else
				{
					$mydelete =~ s/\?/\'$fieldvals[$i]\'/;
				}
			}
			else
			{
				$mydelete =~ s/\?/NULL/s;
			}
		}
		$DIALOG2->configure(
				-text => "Do: \"$mydelete\" (SURE?)");
		my ($usrres) = $DIALOG2->Show();

		return (0)  if $usrres ne $OK;
		if ($noplaceholders)
		{
			$res = $dB->do($mydelete) 
					|| &show_err(" DELETE ERROR: ".$dB->err.':'.$dB->errstr);
			unless ($dB->err)  #SYBASE/TDS ALWAYS SEEMS TO RETURN -1!
			{
				$res = '1 or more'  if ($res < 0);
			}
		}
		else
		{
			$res = $dB->do($myPHdelete,{},@fieldvals) 
					|| &show_err(" DELETE ERROR: ".$dB->err.':'.$dB->errstr);
		}
	}
	else
	{
		$DIALOG2->configure(
				-text => "Do: \"$mydelete\" (SURE?)");
		my ($usrres) = $DIALOG2->Show();

		return (0)  if $usrres ne $OK;
		$res = $dB->do($mydelete) 
				|| &show_err(" DELETE ERROR: ".$dB->err.':'.$dB->errstr);
	}
	$res = 'No'  if (!defined($res) || !$res || $res eq 'OK' || $res eq '0E0');
	#$statusText->insert('end',".......DID: $delstr ($res records deleted)!\n")  unless ($$dbi_err != 0);
	$statusText->insert('end',".......DID: $delstr ($res records deleted)!\n");

	$statusText->see('end');
	#&ora_commit($dB);
	&docommit  unless ($nocommit);
}

sub editfid
{
	$xpopup->destroy  if (Exists($xpopup));
	$myfile = $fileText->get;
	if (open(INFILE,"<$myfile"))
	{
		binmode INFILE;    #20000404
		$xpopup = $MainWin->Toplevel;
		$xpopup->title("File: $myfile");

		my $xpopupFrame = $xpopup->Frame;
		$xpopupText = $xpopupFrame->Text(
				-relief => 'sunken',
				-setgrid=> 1,
				-wrap	=> 'none',
				-height => 25,
				-width  => 48);
		$xpopupText->bind('<FocusIn>' => [\&textfocusin]);

		my $xpopupScrollY = $xpopupFrame->Scrollbar(
				-relief => 'sunken',
				-orient => 'vertical',
				-command=> [$xpopupText => 'yview']);
		$xpopupText->configure(-yscrollcommand=>[$xpopupScrollY => 'set']);

		$xpopupScrollY->pack(-side=>'right', -fill=>'y');
		$xpopupScrollX = $xpopupFrame->Scrollbar(
				-relief => 'sunken',
				-orient => 'horizontal',
				-command=> [$xpopupText => 'xview']);
		$xpopupText->configure(
				-xscrollcommand=>[$xpopupScrollX => 'set']);
		$xpopupScrollX->pack(
				-side   => 'bottom', -fill=>'x');

		my $btnFrame = $xpopup->Frame;
		$btnFrame->pack(
				-side	=> 'bottom',
				-padx => '2m',
				-pady => '2m',
			#-expand	=> 'yes',
				-fill	=> 'x');
		$xpopupFrame->pack(
				-fill	=> 'both',
				-expand	=> 'yes');
		$xpopupText->pack(
				-side	=> 'left',
				-expand	=> 'yes',
				-fill	=> 'both');


		my $okButton = $btnFrame->Button(
				-text => 'Save',
				-underline => 0,
				-command => [\&savechgs]);
		$okButton->pack(
				-side => 'left',
				-expand=> 1);

		my $copyButton = $btnFrame->Button(
				-text => 'Copy',
				-underline => 0,
				-command => sub {&doCopy();});
		$copyButton->pack(
				-side=>'left', 
				-expand => 1);

		my $canButton = $btnFrame->Button(
				-text => 'Cancel',
				-underline => 0,
				-command => [$xpopup => 'destroy']);
		$canButton->pack(
				-side => 'left',
				-expand=> 1);

		my ($myrsdelim,$myrjdelim) = &getdelims(1);  #FETCH RECORD DELIMITERS.
		my ($slash) = $/;
		$/ = $myrjdelim;
		$abortit = 0;
		while (<INFILE>)
		{
			last  if ($abortit);
			if ($myrjdelim =~ /\n$/)
			{
				$xpopupText->insert('end',$_);
			}
			else
			{
				$xpopupText->insert('end',"$_\n");
			}
		}
		$/ = $slash;
		$okButton->bind('<Return>' => "Invoke");
		$canButton->bind('<Return>' => "Invoke");
		$xpopup->bind('<Alt-s>' => [$okButton => "Invoke"]);
		$xpopup->bind('<Alt-c>' => [$canButton => "Invoke"]);
		$xpopup->bind('<Escape>' => [$canButton => "Invoke"]);
		$okButton->focus;
		close (INFILE);
	}
	else
	{
		&show_err("..Couldn't read flatfile:  \"$myfile\"!\n");
	}
}

sub savechgs
{
	if (open(OUTFILE2,">$myfile"))
	{
		binmode OUTFILE2;    #20000404
		my ($fidcontents) = $xpopupText->get('0.0','end');
		my ($myrsdelim,$myrjdelim) = &getdelims(1);  #FETCH RECORD DELIMITERS.
		chomp ($fidcontents);
		$fidcontents =~ s/\n//g  unless ($myrjdelim =~ /\n$/);
		print OUTFILE2 $fidcontents;	
		close (OUTFILE2);
	}
	else
	{
		&show_err("..Couldn't save flatfile:  \"$myfile\"!\n");
	}
	$xpopup->destroy;
}

sub inputscr
{
	my ($whichinput) = shift;

	my ($fstart, $fend);
	if ($whichinput == 0)  #PROMPTING FOR DATA.
	{
		@orderlist = $orderList->get('0','end');
		@orderlist = $fieldList->get('0',$fieldList->index('end')-2)  if ($#orderlist < 0); #ADDED 11/06/96 jwt
	}
	else                   #PROMPTING FOR WHERE-stuff.
	{
		@orderlist = $whereList->get('0','end');
	}
	@fields = $fieldList->get('0',$fieldList->index('end')-2);
#	if ($selcsr = $dB->prepare("select * from $mytable", {ldap_sizelimit => 1, sprite_sizelimit => 1}))
	if ($dbtype eq 'mysql')
	{
		$selcsr = $dB->prepare("LISTFIELDS $mytable", {'mysql_use_result' => 1})
	}
	elsif ($dbtype eq 'Sybase')  #THIS MAY WORK W/OTHER dB'S, BUT I DON'T KNOW, PLEASE SOMEONE ENLIGHTEN ME!
	{
		$selcsr = $dB->prepare("select top 1 * from $mytable")
				|| &show_err("fields: prepare: ".$dB->err.':'.$dB->errstr);
	}
	else
	{
		$selcsr = $dB->prepare("select * from $mytable", {ldap_sizelimit => 1, sprite_sizelimit => 1})
	}
	if ($selcsr)
	{
		$selcsr->execute;
		#@types = &ora_types($selcsr);
		#@lens = &ora_lengths($selcsr);
		@types = @{$selcsr->{TYPE}};
		foreach $i (0..$#types)
		{
			$types[$i] = &type_name($types[$i]);
		}
		@lens = @{$selcsr->{PRECISION}};
		if ($dbtype eq 'Oracle')
		{
			my @oralens = @{$selcsr->{'ora_lengths'}};   #ORACLE-SPECIFIC.
			for (my $i=0;$i<=$#lens;$i++)
			{
				$lens[$i] ||= $oralens[$i];
			}
		}
		elsif ($dbtype eq 'mysql')
		{
			@lens = @{$selcsr->{mysql_length}};
		}
		$selcsr->finish;
	}

	$StuffEnterred = 0;
	for ($fstart=0; $fstart<=$#orderlist; $fstart+=12)
	{
		$fend = $fstart + 11;
		$fend = $#orderlist  if ($fend > $#orderlist);
		&inputblk($whichinput, $fstart, $fend);
		last  unless ($StuffEnterred);
	}
}

sub inputblk
{
	my ($whichinput, $fstart, $fend) = @_;

	my ($i, $j, $mylen);

	$xpopup->destroy  if (Exists($xpopup));
	$xpopup = $MainWin->Toplevel;

	if ($whichinput == 0)  #PROMPTING FOR DATA.
	{
		$xpopup->title('Enter new field data:');
		$valuestuff = ''  unless ($fstart);
	}
	else                   #PROMPTING FOR WHERE-stuff.
	{
		$xpopup->title('Enter WHERE-values:');
		$wherestuff = ''  unless ($fstart);
	}

	my ($btnFrame) = $xpopup->Frame;
	my ($okButton) = $btnFrame->Button(
			-text => 'Ok',
			-underline => 0,
			-command => [\&inputvals, $whichinput, $fstart, $fend]);
	for ($i=$fstart;$i<=$fend;$i++)
	{
		last  if ($i > $fend);
		for ($j=0;$j<=$#fields;$j++)
		{
			if ($fields[$j] eq $orderlist[$i])
			{
				$mylen = $lens[$j];
				$mylen = 9  if ($types[$j] == 12);
				$mylen = 12  if ($types[$j] == 2 || $types[$j] == 3 || $types[$j] == 23
				|| $types[$j] == 24);
				$tolong = $mylen;
				if ($mylen > 80)
				{
					$mylen = 80;
				}
			}
		}
		#$fi = $orderlist[$i];
		$fi = $i;
		$eLen{$fi} = $mylen;
		$mylen = 4  if (${'eS'.$whichinput.'x'.$i} =~ /^is/);
		$mylen = 40  if ($mylen < 40 && ${'eS'.$whichinput.'x'.$i} eq 'in');
		#eval (" \$eF${fi} = \$xpopup->Frame;
		$eval = " \$eF${fi} = \$xpopup->Frame;
		\$eF${fi}->pack(
				-side	=> 'top',
				-fill   => 'x',
				-padx   => '2m',
				-pady   => '1m');";
		if ($newwhere && $whichinput == 1)
		{
			$eval .= "
					\$eR${whichinput}x${fi} = ' or '; ";
		}
		else
		{
			$eval .= "
					\$eR${whichinput}x${fi} ||= ' or '; ";
		}
		$eval .= "
				\$eRmenu${fi} = \$eF${fi}->JOptionmenu(
				-textvariable => \\\$eR${whichinput}x${fi},
				-relief => 'raised',
				-highlightthickness => 2,
				-takefocus => 1,
				-command => sub { \$eSmenu${fi}->focus },
				-options => [' or ',' and '])
				->pack(-side => 'left');"  if ($i && $whichinput == 1);
		$eval .= "
				\$eL${fi} = \$eF${fi}->Label(-text => \"$orderlist[$fi]:\");
		\$eL${fi}->pack(-side => 'left',
				-fill => 'x',
				-padx=>'2m');";
		if ($newwhere && $whichinput == 1)
		{
			$eval .= "
					\$eS${whichinput}x${fi} = '=';  ";
		}
		else
		{
			$eval .= "
					\$eS${whichinput}x${fi} ||= '=';  ";
		}
		$eval .= "
				\$eSmenu${fi} = \$eF${fi}->JOptionmenu(
				-textvariable => \\\$eS${whichinput}x${fi},
				-relief => 'raised',
				-highlightthickness => 2,
				-takefocus => 1,
				-command => sub {
						if (\$eS${whichinput}x${fi} =~ /^is/)
						{
							\$eTv${whichinput}x${fi} = 'NULL';
							\$eT${fi}->configure( -state => 'disabled',
								-takefocus => 0, -relief => 'flat',
								-width => 4);
						}
						elsif (\$eS${whichinput}x${fi} =~ /^in/)
						{
							\$eTv${whichinput}x${fi} = '';
							\$eT${fi}->configure( -state => 'normal',
								-takefocus => 1, -relief => 'sunken',
								-width => 40);
							\$eT${fi}->focus;
						}
						else
						{
							\$eTv${whichinput}x${fi} = '';
							\$eT${fi}->configure( -state => 'normal',
								-takefocus => 1, -relief => 'sunken',
								-width => \$eLen{$fi});
							\$eT${fi}->focus;
						}
				},
				-options => \$oplist)
				->pack(-side => 'left');"  if ($whichinput == 1);
		if ($newwhere)
		{
			$eval .= "
					\$eTv${whichinput}x${fi} = '';  ";
		}
		else
		{
			$eval .= "
					\$eTv${whichinput}x${fi} ||= '';  ";
		}
		$eval .= "
				\$eT${fi} = \$eF${fi}->Entry(
				-textvariable => \\\$eTv${whichinput}x${fi},
				-relief => ((\$eS${whichinput}x${fi} =~ /^is/) ? 'flat' : 'sunken'),
				-state => ((\$eS${whichinput}x${fi} =~ /^is/) ? 'disabled' : 'normal'),
				-takefocus => ((\$eS${whichinput}x${fi} =~ /^is/) ? 0 : 1),
				-width  => $mylen);
		\$eT${fi}->bind('<FocusIn>' => [\\\&textfocusin]);
		\$eT${fi}->pack(
				-side   => 'left',
				-padx   => '2m',
				-pady   => '1m');
		if (\$tolong > 80)
		{
			\$eX${fi} = \$eF${fi}->Label(-text => \"(\$tolong)\");
			\$eX${fi}->pack(-side => 'left');
		}
		\$eT${fi}->focus  if (\$i == $fstart);
		if (\$i == \$fend && \$fend < \$#orderlist)
		{
			\$contF = \$xpopup->Frame;
			\$contF->pack(
					-side	=> 'top',
					-fill   => 'x',
					-padx   => '2m',
					-pady   => '1m');

			\$contL = \$contF->Label(-text => '...');
			\$contL->pack(-side => 'left',
					-fill => 'x',
					-padx=>'2m');
		}
		;
		\$eT${fi}->bind('<Return>' => [\$okButton => \"Invoke\"])  if (\$i==\$fend);
		";
		eval $eval;
	}

	$okButton->pack(-side=>'left', -expand=>1, -padx=>'2m', -pady=>'2m');
	$okButton->bind('<Return>' => "Invoke");

	my ($canButton) = $btnFrame->Button(
			-padx => 11,
			-pady =>  4,
			-text => 'Cancel',
			-underline => 0,
			-command => [sub{$StuffEnterred = 0; $xpopup->destroy}]);
	$canButton->pack(-side=>'left', -expand=>1, -padx=>'2m', -pady=>'2m');
	$canButton->bind('<Return>' => "Invoke");
	my ($clearButton) = $btnFrame->Button(
			-padx => 11,
			-pady =>  4,
			-text => 'cleaR',
			-underline => 4,
			-command => [sub
	{
		for ($i=$fstart;$i<=$fend;$i++)
		{
			####${"eR${whichinput}x$i"} = ' and ';  #THIS CAUSETH CLEAR BUTTON TO CHANGE OR TO AND, NOT VERY DESIRABLE.
			${"eS${whichinput}x$i"} = '=';
			${"eTv${whichinput}x$i"} = '';
		}
	}
	]);
	$clearButton->pack(-side=>'left', -expand=>1, -padx=>'2m', -pady=>'2m');
	$xpopup->bind('<Alt-o>' => [$okButton => "Invoke"]);
	#$xpopup->bind('<Alt-c>' => sub {&doCopy();});
	$xpopup->bind('<Alt-v>' => sub {&doPaste();});
	#$xpopup->bind('<Escape>' => [$canButton => "Invoke"]);
	$xpopup->bind('<Escape>' => sub
	{
		(${"eTv${whichinput}x${fstart}"} =~ /\S/) ? 
		$clearButton->Invoke : $canButton->Invoke;
	}
	);

	$btnFrame->pack(-side => 'bottom');
	$xpopup->waitWindow;   #THIS MAKES THIS POPUP MODAL!
}

sub inputvals
{
	my ($whichinput, $fstart, $fend) = @_;

	my ($v);

	($myasdelim,$myajdelim) = &getdelims(2);
	if ($whichinput == 0)
	{
		@orderlist = $orderList->get('0','end');
		@orderlist = $fieldList->get('0',$fieldList->index('end')-2)  if ($#orderlist < 0); #ADDED 11/06/96 jwt
		for ($i=$fstart;$i<=$fend;$i++)
		{
			#$fi = $orderlist[$i];
			$fi = $i;
			$valuestuff .= $myajdelim  if ($i > 0);
			$v = '';
			eval ("
					\$v .= \$eTv${whichinput}x${fi};
			\$v =~ s/\$myajdelim/\x02/g;
			");
			eval ("\$valuestuff .= \$v;");
		}
	}
	else
	{
		@orderlist = $whereList->get('0','end');
		@ops = ()  if ($whichinput == 1);
		@relops = ()  if ($whichinput == 1);
		for ($i=$fstart;$i<=$fend;$i++)
		{
			#$fi = $orderlist[$i];
			$fi = $i;
			$wherestuff .= $myajdelim  if ($i > 0);
			$wherestuff .= $orderlist[$fi] . '=';
			$v = '';
			eval ("
					\$v = \$eT${fi}->get;
			\$v =~ s/\$myajdelim/\x02/g;
			");
			eval ("
					\$op = \$eS${whichinput}x${fi};
					\$op =~ s/\\^/\\~/;   #ADDED 20011018
			push (\@ops,(' '.\$op));
			")  if ($whichinput == 1);
			eval ("
					push (\@relops,\$eR${whichinput}x${fi});
			")  if ($i && $whichinput == 1);
			$wherestuff .= $v;
			###$wherestuff .= 'NULL'  unless ($v gt '');
		}
	}
	$xpopup->destroy;	
	$StuffEnterred = 1;
	$newwhere = 0;
}

sub getdelims
{
	my ($whichdelim) = shift;

	my ($mysdelim,$myjdelim);

	if ($whichdelim == 2)
	{
		$mysdelim = $adelimText->get;
	}
	elsif ($whichdelim)
	{
		$mysdelim = $rdelimText->get;
	}
	else
	{
		$mysdelim = $delimText->get;
	}
	if ($mysdelim eq "\$")
	{
		$myjdelim = $mysdelim;
		$mysdelim = '\\' . $mysdelim;
	}
	else
	{
		$mysdelim = eval("return(\"$mysdelim\");")  if ($whichdelim);
		$myjdelim = $mysdelim;
		$mysdelim = "\Q$mysdelim\E";
		#$mysdelim = '\\' . $mysdelim  if ($mysdelim eq "\$");
	}
	return ($mysdelim,$myjdelim);
}
sub setdfltfmt
{
	my ($mysdelim, $i, $j, $mylen, @types, @lens);

	$mysdelim = $delimText->get;
	if ($usefmt >= 2)
	{
		###$fmtText->delete('0.0','end');
		$myfmt = '';
		$fmtTextSel = $myfmt;
		if ($mysdelim =~ /^[=\-\._]/)
		{
			$delimText->delete('0.0','end');
			$delimText->insert('end',',');
		}
		$usefmt = 0;
	}
	else
	{
		if ($mysdelim !~ /^[=\-\._]/)
		{
			$delimText->delete('0.0','end');
			$delimText->insert('end','-');
		}
		###$fmtText->delete('0.0','end');
		$myfmt = '';
		$fmtTextSel = $myfmt;
		@orderlist = $orderList->get('0','end');
		@orderlist = $fieldList->get('0',$fieldList->index('end')-2)  if ($#orderlist < 0);
		my $gotColInfo = 0;
		my $extraFields = $valusText->get;
		my @extraFieldList;
		@extraFieldList = split(/\,\s*/, $extraFields)
				if ($extraFields =~ s/^.*\\h=//);

		if ($use eq 'sql')   #NOTE: SECURITY HOLE: CURRENTLY ONLY CHECKS 1ST TABLE!!!
		{
			my $mymyselect = $sqlText->get('0.0','end');
			$mymyselect =~ s/;+$//;

			#NEXT 6 LINES ADDED 20030920 TO SUPPORT A "READONLY" MODE!

			if ($mymyselect =~ /^\s*select/i)
			{
				$mymyselect =~ s/^\s*select/select top 1 /i  if ($dbtype eq 'Sybase');
				$mymyselect .= ' LIMIT 1'  if ($dbtype eq 'mysql');
				$fieldcsr = $dB->prepare($mymyselect, {ldap_sizelimit => 1, sprite_sizelimit => 1}) 
						|| &show_err("sql select: OPEN ERROR: ".$dB->err.':'.$dB->errstr);

				$fieldcsr->execute;
				@orderlist = @{$fieldcsr->{NAME}};
				@fields = @orderlist;
				$gotColInfo = 1  if ($#orderlist >= 0);
				@types = @{$fieldcsr->{TYPE}};
				@lens = @{$fieldcsr->{PRECISION}};
				$fieldcsr->finish();
			}
		}
#		if ($selcsr = $dB->prepare("select * from $mytable", {ldap_sizelimit => 1, sprite_sizelimit => 1}))
		unless ($gotColInfo)
		{
			@fields = $fieldList->get('0',$fieldList->index('end')-2);
			if ($dbtype eq 'mysql')
			{
				$selcsr = $dB->prepare("LISTFIELDS $mytable", {'mysql_use_result' => 1});
			}
			elsif ($dbtype eq 'Sybase')  #THIS MAY WORK W/OTHER dB'S, BUT I DON'T KNOW, PLEASE SOMEONE ENLIGHTEN ME!
			{
				$selcsr = $dB->prepare("select top 1 * from $mytable")
						|| &show_err("fields: prepare: ".$dB->err.':'.$dB->errstr);
			}
			else
			{
				$selcsr = $dB->prepare("select * from $mytable", {ldap_sizelimit => 1, sprite_sizelimit => 1})
			}
			if ($selcsr)
			{
				$selcsr->execute;
				#@types = &ora_types($selcsr);
				@types = @{$selcsr->{TYPE}};
				@lens = @{$selcsr->{PRECISION}};
				if ($dbtype eq 'Oracle')
				{
					my @oralens = @{$selcsr->{'ora_lengths'}};   #ORACLE-SPECIFIC.
					for (my $i=0;$i<=$#lens;$i++)
					{
						$lens[$i] ||= $oralens[$i];
					}
				}
				elsif ($dbtype eq 'mysql')
				{
					@lens = @{$selcsr->{mysql_length}};
				}
				#&ora_close($selcsr);
				$selcsr->finish();
			}
		}

		@headerlist = ();
		my $thisHeader;
		$headers = 1;
		for ($i=0;$i<=$#orderlist;$i++)
		{
			for ($j=0;$j<=$#fields;$j++)
			{
				if ($fields[$j] eq $orderlist[$i])
				{
					$thisHeader = $extraFieldList[$i] || $fields[$j];
					push (@headerlist, $thisHeader);
					$myfmt .= '@';
					$mylen = $lens[$j] || 500;
					if ($dbtype eq 'Sybase' && $mylen == 4)  #FIX TDS GLITCH?
					{
						if ($types[$j] == 4)   #NUMBER
						{
							$mylen = 10;
						}
						elsif ($types[$j] == 9)  #DATE
						{
							$mylen = 19;
						}
					}
					elsif ($dbtype eq 'Pg' && $mylen == 4)  #FIX PostgreSQL DATEs
					{
						if ($types[$j] == 9)  #DATE
						{
							$mylen = 19;
						}
					}
					#--$mylen = 9  if ($types[$j] == 12);
					#--$mylen = 12  if ($types[$j] == 2 || $types[$j] == 3 || $types[$j] == 23
					#	 || $types[$j] == 24);
#					if ($types[$j] == 7)         #MUST BE SOME "CURRENCY" TYPE?
#					{
#						$myfmt .= '$######.##';
#					}
					$mylen = length($thisHeader)  if ($headers && $mylen < length($thisHeader));  #ADDED 20050509 TO ENSURE HEADERS VISIBLE.
					if ($types[$j] <= 1 || $types[$j] == 12 || !$lens[$j])       #STRINGS!
					{
						if (!$usefmt && $mylen > 50)
						{
							chop $myfmt;
							$myfmt .= '%-50W';  #OFFER TO WRAP LONG ONES!
						}
						else
						{
							$myfmt .= ($mylen - 1) . '<'  if ($mylen > 1);
						}
					}
					else
					{
						$mylen = 10  if (!$usefmt && $mylen == 40); #ORACLE'S DEFAULT IS UGLY!
						$myfmt .= ($mylen - 1) . '>'  if ($mylen > 1);
					}
					$myfmt .= ' ';
#2					$fmtTextSel = $myfmt;
#2					###$fmtText->insert('end',$myfmt);
#2					$fmtText->Subwidget('entry')->focus;
					$gotColInfo = 1;
				}
			}
		}
		unless ($gotColInfo)
		{
			for ($i=0;$i<=$#extraFieldList;$i++)
			{
				$myfmt .= '@' . (length($extraFieldList[$i]) - 1) . '<'  if ($extraFieldList[$i]);
				$myfmt .= ' ';
				push (@headerlist, $extraFieldList[$i]);
			}
		}
		$fmtTextSel = $myfmt;
		###$fmtText->insert('end',$myfmt);
		$fmtText->Subwidget('entry')->focus;
		++$usefmt;
	}
}

sub docommit
{
	unless ($dB->{AutoCommit})
	{
		$dB->commit || &show_err("commit error: ".$dB->err.':'.$dB->errstr);
	}
	$statusText->insert('end', 
			"------------------------- COMMITTED! -------------------------\n");
	$statusText->see('end');
	$statusText->update;
}

sub dorollback
{
	if ($dB->{AutoCommit} || !$nocommit)
	{
		&show_err("Rollback ineffective with Autocommit or Forced commit!\n");
	}
	else
	{
		$dB->rollback;
		$statusText->insert('end', 
				"------------------------ ROLLED BACK! ------------------------\n");
		$statusText->see('end');
		$statusText->update;
	}		
}

sub dodescribe
{
	my ($fmt) = shift;

	goto SKIP_TK  if ($fmt == 4);

	$tpopup->destroy  if (Exists($tpopup));
	$tpopup = $MainWin->Toplevel;
	$tpopup->title("Description of \"$mytable\"");

	my $tpopupFrame = $tpopup->Frame;
	my $tpopupText = $tpopupFrame->ROText(
			-font	=> $fixedfont,    #PC-SPECIFIC.
			-relief => 'sunken',
			-setgrid=> 1,
			-wrap	=> 'none',
			-height => 25,
			-width  => 54);

	my $tpopupScrollY = $tpopupFrame->Scrollbar(
			-relief => 'sunken',
			-orient => 'vertical',
			-command=> [$tpopupText => 'yview']);
	$tpopupText->configure(-yscrollcommand=>[$tpopupScrollY => 'set']);
	$tpopupText->bind('<FocusIn>' => [\&textfocusin]);

	$tpopupScrollY->pack(-side=>'right', -fill=>'y');

	my $buttonFrame = $tpopup->Frame->pack(
			-side=>'bottom', 
			-fill => 'x',
			-padx=>'2m', 
			-pady=>'2m');
	my $okButton = $buttonFrame->Button(
                #-padx => 11,
                #-pady =>  4,
			-text => 'Ok',
			-underline => 0,
			-command => [$tpopup => 'destroy']);
        #$okButton->pack(-side=>'left', -padx=>'2m', -pady=>'2m');
	$okButton->pack(-side=>'left', -expand => 1);
	my $copyButton = $buttonFrame->Button(
                #-padx => 11,
                #-pady =>  4,
			-text => 'Copy',
			-underline => 0,
			-command => sub {&doCopy();});
        #$copyButton->pack(-side=>'left', -padx=>'2m', -pady=>'2m');
	$copyButton->pack(-side=>'left', -expand => 1);
	$tpopupFrame->pack(
			-side	=> 'top',
			-expand	=> 'yes',
			-fill	=> 'both',
			-padx	=> '2m',
			-pady	=> '2m');
	$tpopupText->pack(
			-side	=> 'left',
			-expand	=> 'yes',
			-fill	=> 'both');

	$tpopup->bind('<Return>' => [$okButton => "Invoke"]);
	$tpopup->bind('<Alt-o>' => [$okButton => "Invoke"]);
	$tpopup->bind('<Escape>' => [$okButton => "Invoke"]);
	$okButton->focus;

SKIP_TK: ;

	my (@fieldlist) = $orderList->get('0','end');

	my ($mysel) = join(',',@fieldlist);
	$mysel = '*'  if ($#fieldlist < 0);
	my ($myselect) = "select $mysel from ".$mytable;
	$myselect = "LISTFIELDS $mytable"  if ($dbtype eq 'mysql' && $mysel eq '*');
	#$fieldcsr = &ora_open($dB,$myselect)
	#$fieldcsr = $dB->prepare($myselect)  #CHGD. TO NEXT FOR SPEED 20020530.
	if ($dbtype eq 'mysql')
	{
		$fieldcsr = $dB->prepare($myselect, {mysql_use_result => 1}) 
				|| &show_err("fields: PREPARE ERROR: ".$dB->err.':'.$dB->errstr);
	}
	else
	{
		$fieldcsr = $dB->prepare($myselect, {ldap_sizelimit => 1, sprite_sizelimit => 1}) 
				|| &show_err("fields: PREPARE ERROR: ".$dB->err.':'.$dB->errstr);
	}
	$fieldcsr->execute;

	@fieldlist = @{$fieldcsr->{NAME}};   #ADDED 20030620.
	#my (@types) = &orax_types($fieldcsr,1);
	my (@types) = @{$fieldcsr->{TYPE}};
	foreach $i (0..$#types)
	{
		$types[$i] = &type_name($types[$i]);
		$types[$i] .= "[$types[$i]]"  if ($d);
	}
	my (@nlens) = @{$fieldcsr->{PRECISION}};
	#my (@lens) = @nlens;
	### MYSQL:  my (@lens) = @{$fieldcsr->{'ora_lengths'}};   #ORACLE-SPECIFIC.
	my (@lens);
	@lens = @{$fieldcsr->{PRECISION}};
	if ($dbtype eq 'Oracle')
	{
		my @oralens = @{$fieldcsr->{'ora_lengths'}};   #ORACLE-SPECIFIC.
		for (my $i=0;$i<=$#lens;$i++)
		{
			$lens[$i] ||= $oralens[$i];
		}
	}
	elsif ($dbtype eq 'mysql')
	{
		@lens = @{$fieldcsr->{mysql_length}};
	}
	my (@scales) = @{$fieldcsr->{SCALE}};
	my ($myline) = '\n';
	my ($j) = 0;
	if ($fmt == 1)
	{
		$tpopupText->configure(-wrap => 'word');
		$tpopupText->insert('end', join(', ',@fieldlist));
		$tpopupText->tagAdd('sel', '0.0','insert');
		$j = 25;
	}
	elsif ($fmt == 2)
	{
		$tpopupText->configure(-wrap => 'word');
		$_ = ':'.join(', :',@fieldlist);
		tr/A-Z/a-z/;
		$tpopupText->insert('end', $_);
		$tpopupText->tagAdd('sel', '0.0','insert');
		$j = 25;
	}
	elsif ($fmt == 3 || $fmt == 4)
	{
		my $mytext = "create table $mytable (\n";
		foreach (@fieldlist)
		{
			#$types[$j] .= '(' . $lens[$j] . ')'  unless ($types[$j] eq 'NUMBER');
			if ($types[$j] eq 'NUMBER')
			{
				$types[$j] .= '(' . $nlens[$j] . ',' . $scales[$j] . ')'
			}
			#elsif ($types[$j] ne 'LONG')
			elsif ($types[$j] !~ /(LONG|RAW)/)
			{
				$types[$j] .= '(' . $lens[$j] . ')'
			}
			#$myline = sprintf "%-32s %-14s", $_, $types[$j];
			$myline = "\t" . sprintf("%-32s",$_) . $types[$j];
			$myline .= ','  unless ($_ eq $fieldlist[$#fieldlist]);
#print "-???- cash=$_= FL($#fieldlist) =$fieldlist[$#fieldlist]=\n";
			if ($_ eq $fieldlist[$#fieldlist])
			{
#!!-THE NEXT 5 LINES ARE USED BY THE CALL AT APPROX. LINE 1984 (FMT==4)
				my $primarykeys = shift;
				if ($primarykeys)
				{
					$myline .= ",\n\t\tprimary key ($primarykeys)";
				}
				else  #TRY TO FETCH PRIMARY KEY LIST FROM DBI (NEWER FEATURE):
				{
					my @primkeys = $dB->primary_key(undef,undef,$mytable);
#print "----- primkeys=".join(', ', @primkeys)."= table=$mytable=\n";
					if ($#primkeys >= 0)
					{
						$myline .= ",\n\t\tprimary key (".join(', ', @primkeys).")";
					}
				}
			}
			$mytext .= "$myline\n";
			++$j;
		}
		$mytext .= ")\n";
		if ($fmt == 3)
		{
			$tpopupText->insert('end', $mytext);
			$tpopupText->tagAdd('sel', '0.0','insert');
		}
		else
		{
			$ddpath .= $osslash  if ($ddpath && $ddpath !~ m#${osslash}$#);
			my $writeword = (-e "${ddpath}${tablename}.tdf") ? 'Modified' 
					: 'Created';
			if (open (OUTFILE2, ">${ddpath}${mytable}.tdf"))
			{
				print OUTFILE2 $mytext;
				close OUTFILE2;
				$statusText->insert('end',"..$writeword TDF file: \"${ddpath}${mytable}.tdf\".\n")  unless ($dB->err);
#				$statusText->see('end');
			}
			return;
		}
	}
	else
	{
		foreach (@fieldlist)
		{
			#$types[$j] .= '(' . $lens[$j] . ')';
			if ($types[$j] eq 'NUMBER')
			{
				$types[$j] .= '(' . $nlens[$j] . ',' . $scales[$j] . '),'
					}
			elsif ($types[$j] ne 'LONG')
			{
				$types[$j] .= '(' . $lens[$j] . '),'
					}
			$myline = sprintf "%-32s %-14s", $_, $types[$j];
			$tpopupText->insert('end',"$myline\n");
			++$j;
		}
	}
	if ($j < 25)
	{
		$tpopupText->configure('-height' => $j+3);
	}
	$fieldcsr->finish();   #ADDED 20020711
}

sub clearFn
{
	$orderList->delete('0.0','end');
	$whereList->delete('0.0','end');
	$ordbyList->delete('0.0','end');
	$valusText->delete('0.0','end');
	$sqlText->delete('0.0','end');
	$orderSel = 'order';
}

sub doSave
{
	my $mytitle = "Select delimited flatfile:";
	my ($create) = 1;
	my ($fileDialog) = $MainWin->JFileDialog(
			-Title=>$mytitle,
			-Path => $startfpath || $ENV{PWD},
			-History => 12,
			-HistFile => "$ENV{HOME}.sqlhist",
			-Create=>$create);

	$myfile = $fileDialog->Show();
	#$startfpath = $fileDialog->{Configure}{-Path};
	$startfpath = $fileDialog->getLastPath();
	if ($myfile =~ /\S/)
	{
		system "cp .sqlout.tmp $myfile";
	}
	else
	{
		&show_err("e:COULD NOT SAVE TO \"$myfile\"!\n");
		print "e:COULD NOT SAVE TO \"$myfile\"!\n";
	}
}

sub initsec
{
	my ($table, @users);

	$me = `id`;
	$me =~ /\(([^)]+)\)/;
	$me = $1;
	$me = 'everyone'  unless ($me =~ /\w/);
	print "-user=$me.\n";
	my $tablefid = $ENV{HOME} . '/.sqlpl.' . &tolower(substr($dbtype,0,3));
	unless (-e $tablefid)
	{
		$tablefid = $pgmhome . 'sqlpl.' . &tolower(substr($dbtype,0,3));
	}
	unless (-e $tablefid)
	{
		$tablefid = $pgmhome . 'sqlpl.dat';
	}
	#if (open(IN,"<${pgmhome}sqlpl.dat"))
	if (open(IN,"<$tablefid"))
	{
		while (<IN>)
		{
			chomp;
			($table,@users) = split(/ /);
			push (@ttables,$table);
			$users = "@users";
			push (@tusers,$users);
		}
	}
}

sub chkacc
{
	my ($arg1,$arg2) = @_;

	$arg1 =~ s/\:\w+\./\:/;    #ADDED 20010830!
#print "arg1=$arg1= arg2=$arg2= tablecnt=$#ttables=\n";
	for (0..$#ttables)
	{
		$salt = substr($ttables[$_],0,2);

		if ($ttables[$_] eq $arg1)
		{
			#return (1)  if ($arg1 eq '--'  || $arg1 eq $dbname);
			@users = split(/ /,$tusers[$_]);
			my $crypted;
			foreach $u (@users)
			{
				#return (1)  if ($u eq crypt($arg2,$salt))
				eval { $crypted = crypt($arg2,$salt); };
				#return (1)  if ($u eq $crypted || $@ =~ /excessive paranoia/);
				return (1)  if ($u eq $crypted || $@);
			}
		}
	}
	return (0);
}

sub newSearch
{
	my ($whichTextWidget) = shift;
	my ($newsearch) = shift;

	#my ($clipboard, $curTextWidget);
	my ($clipboard);

	eval
	{
		$clipboard = $MainWin->SelectionGet(-selection => 'PRIMARY');
	}
	;
	unless (defined($clipboard))
	{
		eval
		{
			$clipboard = $whichTextWidget->get('foundme.first','foundme.last');
		}
	}
	unless (defined($clipboard) && $clipboard =~ /\S/)
	{
		eval
		{
			$clipboard = $MainWin->SelectionGet(-selection => 'CLIPBOARD');
		}
		;
	}

	$startattop = 1  if ($newsearch);
	$srchpopup->destroy  if (Exists($srchpopup));
	$srchpopup = $MainWin->Toplevel;
	$srchpopup->title('Search For:');
	$whichTextWidget->tagDelete('foundme');

	$srchText = $srchpopup->Entry(
			-relief => 'sunken',
			-width  => 40)->pack(
			-padx		=> '2m',
			-pady	 => '2m',
			-side		=> 'top');
	my ($srchLabel) = $srchpopup->Label(-text => 'Search for expression');
	$srchText->bind('<FocusIn>' => sub { $curTextWidget = shift;} );
	$srchLabel->pack(
			-fill	=> 'x');
	$srchopts = '-nocase'  if ($newsearch);
	$exactButton = $srchpopup->Radiobutton(
			-text   => 'Exact match?',
			-underline => 0,
			-takefocus      => 1,
			-value		=> '-exact',
			-variable=> \$srchopts);
	$exactButton->pack(
			-side   => 'top',
			-pady   => 12);
	$caseButton = $srchpopup->Radiobutton(
			-text   => 'Case-insensitive?',
			-underline => 5,
			-takefocus      => 1,
			-value	=> '-nocase',
			-variable=> \$srchopts);
	$caseButton->pack(
			-side   => 'top',
			-pady   => 12);
	$regxButton = $srchpopup->Radiobutton(
			-text   => 'Regular-expression?',
			-underline => 0,
			-takefocus      => 1,
			-value	=> '-regexp',
			-variable=> \$srchopts);
	$regxButton->pack(
			-side   => 'top',
			-pady   => 12);

	my ($srchdirFrame) = $srchpopup->Frame;
	$srchdirFrame->pack(-side => 'top', -fill => 'x');
	$srchwards = 1  if ($newsearch);
	$backButton = $srchdirFrame->Radiobutton(
			-text   => 'Backwards?',
			-underline => 0,
			-takefocus      => 1,
			-value	=> 0,
			-variable=> \$srchwards);
	$backButton->pack(
			-side   => 'left',
			-padx 	=> 12,
			-pady   => 12);
	$topCbtn = $srchdirFrame->Checkbutton(
			-text   => 'Start at top?',
			-underline => 0,
			-variable=> \$startattop);
	$topCbtn->pack(
			-side   => 'left',
			-padx 	 => 12,
			-pady   => 12);
	$forwButton = $srchdirFrame->Radiobutton(
			-text   => 'Forwards?',
			-underline => 0,
			-takefocus	=> 1,
			-value  => 1,
			-variable=> \$srchwards);
	$forwButton->pack(
			-side   => 'left',
			-padx 	 => 12,
			-pady   => 12);

	my $btnframe = $srchpopup->Frame;
	$btnframe->pack(-side => 'bottom', -fill => 'x');

	my $okButton = $btnframe->Button(
			-pady => 4,
			-text => 'Ok',
			-underline => 0,
			-command => [\&doSearch,$whichTextWidget,1]);
	$okButton->pack(-side=>'left', -expand=>1, -pady=> 12);
	my $pasteButton = $btnframe->Button(
			-pady => 4,
			-text => 'Paste',
			-underline => 0,
			-command => sub
	{
		eval {$curTextWidget->insert('insert',$clipboard);}  if (defined($clipboard));
		eval {$activewidget->tagRemove('sel','0.0','end');};
	}
	);
	$pasteButton->configure(-state => 'disabled')  unless (defined($clipboard));

	$pasteButton->pack(-side=>'left', -expand=>1, -pady=> 12);
	my $canButton = $btnframe->Button(
			-pady => 4,
			-text => 'Cancel',
			-underline => 0,
			-command => sub {$srchpopup->destroy});
	$canButton->pack(-side=>'left', -expand=>1, -pady=> 12);
	my $clearButton = $btnframe->Button(
			-pady => 4,
			-text => 'Clear',
			-underline => 1,
			-command => sub {$srchText->delete('0','end');});
	$clearButton->pack(-side=>'left', -expand=>1, -pady=> 12);
	$srchpopup->bind('<Escape>'        => [$canButton	=> Invoke]);

	$srchText->bind('<Return>'        => [$okButton	=> 'Invoke']);
	$srchpopup->bind('<Escape>'        => [$canButton	=> 'Invoke']);

	$srchpos = '1.0';
	$lnoffset = 0;

	unless ($newsearch || $srchstr le ' ')
	{
		$srchText->insert('end',$srchstr)  unless ($newsearch || $srchstr le ' ');
	}
#	else
#	{
#		eval
#		{
#			my ($clipboard);
#			$clipboard = $MainWin->SelectionGet(-selection => 'PRIMARY');
#			$srchText->insert('insert',$clipboard);
#			$activewidget->tagRemove('sel','0.0','end');
#		}
#	}
	$srchText->focus;
}

sub doSearch
{
	my ($whichTextWidget) = shift;
	my ($newsearch) = shift;

	#$findMenubtn->entryconfigure('Search again', -state => 'normal');
	#$findMenubtn->entryconfigure('Modify search', -state => 'normal');
	#$againButton->configure(-state => 'normal');
	$srchstr = $srchText->get  if ($newsearch);
	$srchpopup->destroy  if (Exists($srchpopup));

	$srchpos = '0.0'  if ($whichTextWidget->index('insert') >= $whichTextWidget->index('end') - 1);
	$lnoffset = !$newsearch;
	$srchpos = $whichTextWidget->index('insert')  unless ($newsearch && $startattop);
	$startattop = 0;
	if ($srchwards)
	{
		$srchpos = $whichTextWidget->search(-forwards, $srchopts, -count => \$lnoffset, '--', $srchstr, $srchpos, 'end');
	}
	else
	{
		my ($l) = length($srchstr) || 0;
		$srchpos = $whichTextWidget->index("insert - $l char")  if ($l > 0);
		$srchpos = $whichTextWidget->search(-backwards, $srchopts, -count => \$lnoffset, '--', $srchstr, $srchpos, '0.0');
	}
	if ($srchpos)
	{
		$statusText->insert('end',"..Found \"$srchstr\" at position $srchpos\n");
		$statusText->see('end');
		#$whichTextWidget->tagDelete('sel');
		$whichTextWidget->tagDelete('foundme');
		$whichTextWidget->tagAdd('foundme', $srchpos, "$srchpos + $lnoffset char");
		$whichTextWidget->tagConfigure('foundme',
				-relief => 'raised',
				-borderwidth => 1,
				-background  => 'yellow',
				-foreground     => 'black');
		$srchpos = $whichTextWidget->index("$srchpos + $lnoffset char");
		$whichTextWidget->markSet('insert',$srchpos);
		$srchpos = $whichTextWidget->index('foundme.first')  unless ($srchwards);
		$whichTextWidget->see($srchpos);
		#my ($replstrx) = $replstr;
		#if ($replstr =~ /\S/ and !(defined($v)))
	}	
	else
	{
		&show_err("..Did not find \"$srchstr\".\n");
	}
}

sub show_err
{
	my ($ermsg) = shift;
	$ermsg .= "\n"  if ($ermsg);
	$statusText->insert('end', $ermsg);   #REMOVED 20000303 (NOW STDERR TIED)!  PUT BACK 20060512 (STDERR PRODUCED TOO MUCH NOISE!)
	print STDERR $ermsg;
#	print STDOUT $ermsg;
	$statusText->bell;
	++$errorsfound;
	++$newerrorsfound;
	$statusText->update;
	$statusText->see('end');
	$statusText->update;
	return undef;
}

sub headerfmt
{
	my ($myfmtstmtH) = shift;
	my ($which) = shift;

	unless ($newfmt)
	{
		$myfmtstmtH =~ s/\#>([>]+)/
		my ($ac) = length($1);
		'#'.(2+$ac).'s'/eg;
		$myfmtstmtH =~ s/\#<([<]+)/
		my ($ac) = length($1);
		'#-'.(2+$ac).'s'/eg;
		$myfmtstmtH =~ s/\#\|([\|]+)/
		my ($ac) = length($1);
		'#-'.(2+$ac).'c'/eg;
		$myfmtstmtH =~ s/\#(\d*)</'#-'.(1+$1).'s'/eg;
		$myfmtstmtH =~ s/\#(\d*)>/'#'.(1+$1).'s'/eg;
		$myfmtstmtH =~ s/\#(\d*)\|/'#-'.(1+$1).'c'/eg;
		$myfmtstmtH =~ s/\#(\d+)([Wwc])/\#\-$1$2/g;
		$myfmtstmtH =~ s/\#([\+\-]?)(\d*)[a-zA-Z]/
		my ($linesign,$linenosz) = ($1,$2);
		$linenosz = 0  unless ($linenosz);
		if ($which == 1)
		{
			$fmtreccnt = sprintf("%$linesign${linenosz}s",('-'x$linenosz));
		}
		else
		{
			$fmtreccnt = sprintf("%$linesign${linenosz}s",'LINE#');
		}
		$fmtreccnt
		/eg;
	}
	return ($myfmtstmtH);
}

sub loadcols
{
	my ($slash) = $/;
	$orderList->delete('0.0','end');
	@titles = ();
	my ($myfile) = $fileText->get;
	my ($i, $myrdelim, $myfdelim);

	###$myfmt = $fmtText->get;
	if ($myfmt =~ /\S/)
	{
		my (@types) = @{$fieldcsr->{TYPE}};
		foreach $i (0..$#types)
		{
			$types[$i] = &type_name($types[$i]);
		}
		#my (@lens) = @{$fieldcsr->{PRECISION}};
		my (@lens);
		@lens = @{$fieldcsr->{PRECISION}};
		if ($dbtype eq 'Oracle')
		{
			my @oralens = @{$fieldcsr->{'ora_lengths'}};   #ORACLE-SPECIFIC.
			for (my $i=0;$i<=$#lens;$i++)
			{
				$lens[$i] ||= $oralens[$i];
			}
		}
		elsif ($dbtype eq 'mysql')
		{
			@lens = @{$fieldcsr->{mysql_length}};
		}
		if (open(INFILE,"<$myfile"))
		{
			binmode INFILE;    #20000404
			$_ = <INFILE>;
			if ($headers)
			{
				@titles = split(' ',$_,-1);
				#??? join('|',@titles);
				for ($i=0;$i<=$#titles;$i++)
				{
					$types[$i] = $1  if ($titles[$i] =~ s/\=(.*)//);
					$lens[$i] = $1  if ($types[$i] =~ s/\((\d+).*//);
					$indx = index($_,$titles[$i],$indx);
					####$newfmt .= '@';
					if ($indx > 1)
					{
						if ($types[$j] eq 'NUMBER')
						{
							####$newfmt .= ($indx-1) . '>';
						}
					}
				}
			}
			else
			{
			}
		}
	}
	else
	{
		#$/ = $rdelimText->get;    #ADDED 20000515!
		$myrdelim = $rdelimText->get;    #ADDED 20000515!
		if (open(INFILE,"<$myfile"))
		{
			binmode INFILE;    #20000404
			$_ = <INFILE>;
			if ($myrdelim eq "\$")
			{
				$myrdelim = '\\' . $myrdelim;
			}
			else
			{
				$myrdelim = eval("return(\"$myrdelim\");");
				$myrdelim = "\Q$myrdelim\E";
			}
			s/($myrdelim).*$/$1/s;
			$i = $_;
			$myrdelim = $_;
			$myrdelim =~ s/.*?([^\w\)]+)($)/$1$2/;
			$i =~ s/[\=\(\)\*]//g;
			$myfdelim = ',';
			$myfdelim = $1  if ($i =~ /(\W+)/);
			$myrdelim =~ s/$myfdelim//;
			$/ = $myrdelim;
			chomp;
			#@titles = split($myfdelim,$_,-1);   #CHANGED 2 NEXT 10 LINEs 20000515.
			if ($myfdelim eq "\$")
			{
				$myfdelim = '\\' . $myfdelim;
			}
			else
			{
				$myfdelim = eval("return(\"$myfdelim\");");
#				$myfdelim = "\Q$myfdelim\E";
			}
			@titles = split(/$myfdelim/,$_,-1);
			close INFILE;
			$delimText->delete('0.0','end');
			$rdelimText->delete('0.0','end');
			$delimText->insert('end',&fmtChars($myfdelim));
			$rdelimText->insert('end',&fmtChars($myrdelim));
			$use = 'file';
		}
		for ($i=0;$i<=$#titles;$i++)
		{
			$titles[$i] =~ s/\=.*//;
			#$titles[$i] =~ tr/a-z/A-Z/  if ($dbtype eq 'Oracle' || $dbtype eq 'Sprite');  #CHGD. TO NEXT 20020624!
			$titles[$i] =~ tr/a-z/A-Z/  if ($dbtype eq 'Oracle');
			$orderList->insert('end',$titles[$i]);
		}
	};
	$headers = 1;
	$/ = $slash;
}

sub xloadcols
{
	$orderList->delete('0.0','end');
	($mysdelim,$myjdelim) = &getdelims(0);
	my ($myrsdelim,$myrjdelim) = &getdelims(1);  #FETCH RECORD DELIMITERS.
	my ($slash) = $/;
	$/ = $myrjdelim;
	@titles = ();
	my ($myfile) = $fileText->get;
	unless ($myfile)
	{
		&getfile();
		$myfile = $fileText->get;
	}
	if (open(INFILE,"<$myfile"))
	{
		binmode INFILE;    #20000404
		$_ = <INFILE>;
		chomp;
		@titles = split($mysdelim,$_,-1);
		close INFILE;
	}

	for ($i=0;$i<=$#titles;$i++)
	{
		$titles[$i] =~ s/\=.*//;
		$orderList->insert('end',$titles[$i]);
	}
	$/ = $slash;
}

sub altertable
{
	my ($mytable) = $tableList->get('active');
	my (@fieldlist) = $orderList->get('0','end');
	$use = 'file';
#	$sqlText->insert('0.0',"alter table $mytable modify (\n");
	my ($mysel) = join(',',@fieldlist);
	$mysel = '*'  if ($#fieldlist < 0);
	my ($myselect) = "select $mysel from ".$mytable;
	#$fieldcsr = &ora_open($dB,$myselect)
	$fieldcsr = $dB->prepare($myselect);
	$fieldcsr->execute;
	my (@types) = @{$fieldcsr->{TYPE}};
	foreach $i (0..$#types)
	{
		$types[$i] = &type_name($types[$i]);
	}
	my (@lens);
	@lens = @{$fieldcsr->{PRECISION}};
	if ($dbtype eq 'Oracle')
	{
		my @oralens = @{$fieldcsr->{'ora_lengths'}};   #ORACLE-SPECIFIC.
		for (my $i=0;$i<=$#lens;$i++)
		{
			$lens[$i] ||= $oralens[$i];
		}
	}
	elsif ($dbtype eq 'mysql')
	{
		@lens = @{$fieldcsr->{mysql_length}};
	}
	my (@scales) = @{$fieldcsr->{SCALE}};
	if ($#fieldlist >= 0)
	{
		$sqlText->insert('0.0',"alter table $mytable modify (\n");
		$j = 0;
		foreach (@fieldlist)
		{
			#$types[$j] .= '(' . $lens[$j] . ')'  unless ($types[$j] eq 'NUMBER');
			if ($types[$j] eq 'NUMBER')
			{
				$types[$j] .= '(' . $lens[$j] . ',' . $scales[$j] . ')'
					}
			else
			{
				$types[$j] .= '(' . $lens[$j] . ')'
					}
			#$myline = sprintf "%-32s %-14s", $_, $types[$j];
			#$myline = sprintf("%-32s",$_) . $types[$j] . ',';
			$myline = "\t" . sprintf("%-32s",$_) . $types[$j];
			$myline .= ','  unless ($j >= $#fieldlist);
			$sqlText->insert('end',"$myline\n");
			++$j;
		}
		$sqlText->insert('end',")\n");
		$sqlText->markSet('insert',"2.0");
		$sqlText->markSet('insert',"insert lineend");
	}
	else
	{
		$sqlText->insert('0.0',"alter table $mytable add (\n\t\n)\n");
		#$sqlText->markSet('insert',"insert -2 lines");
		#$sqlText->markSet('insert',"insert +1 chars");
		$sqlText->markSet('insert',"2.1");
	}
	#&ora_close($fieldcsr);
	$fieldcsr->finish;
	$sqlText->focus;	
}

sub pageit
{
	if ($mypaglen > 0 && $headers && !($linecnt % $mypaglen))
	{
		print OUTFILE $ffchar;
		$myfmtstmtH = &headerfmt($mymyfmt,0);
		printf OUTFILE $myfmtstmtH, @headerlist;
		++$linecnt;
		if ($myjdelim ne '')
		{
			$myfmtstmtH2 = &headerfmt($mymyfmt,1);
			printf OUTFILE $myfmtstmtH2, @dashes  if ($myjdelim ne '');
			++$linecnt;
		}
	}
}

sub type_name     #ORACLE-SPECIFIC.
{
	my ($tp) = shift;

	#NOTE:  TYPEHASH IS DEPRECIATED IN FAVOR OF type_info().

	$typehash{'-5'} = 'BIGINT';       #MYSQL-SPECIFIC.
	$typehash{'-4'} = 'LONG RAW';
	$typehash{'24'} = 'LONG RAW';
	$typehash{'-2'} = 'RAW';
	$typehash{'23'} = 'RAW';
	$typehash{'-1'} = 'LONG';
	$typehash{'1'} = 'CHAR';
	$typehash{'3'} = 'NUMBER';
	$typehash{'8'} = 'DOUBLE';
	$typehash{'11'} = 'DATE';
	$typehash{'12'} = 'VARCHAR2';
	$typehash{'15'} = 'VARRAW';

	$typehash{'9'} = 'DATE';          #ORACLE-SPECIFIC.

	$typehash{'2'} = 'NUMBER';        #ODBC-SPECIFIC
	$typehash{'5'} = 'NUMBER';        #ODBC-SPECIFIC
	$typehash{'6'} = 'NUMBER';        #ODBC-SPECIFIC
	$typehash{'4'} = 'NUMBER';        #ODBC-SPECIFIC (M$-ACCESS)
	$typehash{'7'} = 'REAL';
	$typehash{'-6'} = 'TINYINT';      #ODBC-SPECIFIC (M$-SQLSERVER)
	$typehash{'-7'} = 'BOOLEAN';      #ODBC-SPECIFIC (M$-ACCESS)
	$typehash{'-8'} = 'NCHAR';        #ODBC-SPECIFIC (M$-SQLSERVER)
	$typehash{'-9'} = 'NVARCHAR';     #ODBC-SPECIFIC (M$-SQLSERVER)
	$typehash{'-10'} = 'NTEXT';       #ODBC-SPECIFIC (M$-SQLSERVER)
	$typehash{93} = 'SMALLDATETIME';  #ODBC-SPECIFIC (M$-SQLSERVER)
	$typehash{113} = 'BLOB';          #ORACLE-SPECIFIC
	$typehash{1700} = 'NUMBER';       #PostgreSQL-SPECIFIC
	return $dB->type_info($tp)->{TYPE_NAME} || $typehash{"$tp"} || "-unknown($tp)!-";
}

sub exitFn
{
	my $fmtfid = $ENV{HOME} . '/.' . substr($dbuser,0,7) 
			. '.' . &tolower(substr($dbtype,0,3));
	#unless (-e $fmtfid)
	#{
	#	$fmtfid = $ENV{HOME} . '/.sqlplfm.dat';
	#}
	#if (open(OUTFILE,">.sqlplfm.dat"))
	if (open(OUTFILE,">$fmtfid"))
	{
		foreach my $i (@fmtTextList)
		{
			print OUTFILE "$i\n";
		}
		close OUTFILE;
	}
	if (open(OUTFILE,">$ENV{HOME}.sqlfpath.dat"))
	{
		print OUTFILE "$startfpath\n"
	}
	exit (0);
}

sub tolower
{
	my ($str) = shift;
	$str =~ tr/A-Z/a-z/;

	return $str;
}

sub insertfile
{
	$myfile = $fileText->get;
	if (open(INFILE,"<$myfile"))
	{
		binmode INFILE;    #20000404
		while (<INFILE>)
		{
			$sqlText->insert('end',$_);
		}
		close (INFILE);
	}
	else
	{
		&show_err("..Couldn't read flatfile:  \"$myfile\"!\n");
	}
}

sub About
{
	my $aboutText = <<END_TEXT;
$headTitle
(c) 1996,1997,1998,1999,2000,2001
by:  Jim Turner
All rights reserved

docs: $helpurl
END_TEXT
	if ($browser)
	{
		my $aboutDialog = $MainWin->JDialog(
				-title          => $headTitle,
				-text           => $aboutText,
				-bitmap         => 'info',
				-default_button => $OK,
				-escape_button  => $OK,
				-buttons        => [$OK, '~View'],
		);
		if ($aboutDialog->Show() eq '~View')
		{
			system($browser, $helpurl);
		}
	}
	else
	{
		my $aboutDialog = $MainWin->JDialog(
				-title          => $headTitle,
				-text           => $aboutText,
				-bitmap         => 'info',
				-default_button => $OK,
				-escape_button  => $OK,
				-buttons        => [$OK ],
		);
		$aboutDialog->Show();
	}
}

sub setTheme
{
	my ($bg, $fg, $c, $font);
	eval $themeCodeHash{$_[0]};
	my $fgisblack;
	$fgisblack = 1  if ($fg =~ /black/i); #KLUDGE SINCE SETPALETTE/SUPERTEXT BROKE!
	if ($c)
	{
		$MainWin->setPalette($c);
	}
	else
	{
		eval { $MainWin->optionReadfile('~/.Xdefaults') or $MainWin->optionReadfile('/etc/Xdefaults'); };
		$c = $MainWin->optionGet('tkPalette','*');
		$MainWin->setPalette($c)  if ($c);
	}
	&setFont($font)  if ($font =~ /\d/);
}

sub xmlescape
{
	my $res;

	$_[1] =~ s/\&/\&amp;/gs;
	eval "\$_[1] =~ s/(".join('|', keys(%xmleschash)).")/\$xmleschash{\$1}/gs;";
	if ($_[1] =~ /[\x00-\x08\x0A-\x0C\x0E-\x19\x7f-\xff]/)
	{
		return "   <$_[0] xml:encoding=\"base64\">" 
				. MIME::Base64::encode_base64($_[1]) . "</$_[0]>";
	}
	else
	{
		return "   <$_[0]>$_[1]</$_[0]>";
	}	
}

sub doprocess    #ADDED 20030703
{
	$myfile = $fileText->get;
	unless ($myfile)
	{
		my ($fileDialog) = $MainWin->JFileDialog(
				-Title => 'Select file containing an SQL stmt. to process.',
				-Path => $startfpath || $ENV{PWD},
				-History => 12,
				-HistFile => "$ENV{HOME}.sqlhist",
				-Create => 0);
		$myfile = $fileDialog->Show();
		#$startfpath = $fileDialog->{Configure}{-Path};
		$startfpath = $fileDialog->getLastPath();
	}
	if ($myfile)
	{
		if (open(IN,"<$myfile"))
		{
			$sqlText->delete('0.0','end');
			while (<IN>)
			{
				$sqlText->insert('end',$_)
			}
			close (IN);
			$use = 'sql';
			return 1;
		}
		else
		{
			&show_err("..Couldn't open flatfile \"$myfile\" for input ($?)!\n");
			return 0;
		}
	}
}

sub doxeq
{
	$myfile = $fileText->get;
	unless ($myfile)
	{
		my ($fileDialog) = $MainWin->JFileDialog(
				-Title => 'Select file containing SQL to execute.',
				-Path => $startfpath || $ENV{PWD},
				-History => 12,
				-HistFile => "$ENV{HOME}.sqlhist",
				-Create => 0);
		$myfile = $fileDialog->Show();
		#$startfpath = $fileDialog->{Configure}{-Path};
		$startfpath = $fileDialog->getLastPath();
	}
	if ($myfile)
	{
		if (open(IN,"<$myfile"))
		{
			my ($res, $sqlstmt, $stmtcnt);
			$stmtcnt = 0;
			while (<IN>)
			{
				chomp;
				s/\r//g;
				$sqlstmt .= "$_ "  unless (/^(?:\#|\-\-)/);
				$sqlstmt =~ s/\;\s+$//;
				if ($sqlstmt)
				{
#print "-XEQ SQL=$sqlstmt=\n";
					$statusText->insert('end',"..XEQ: $sqlstmt.\n");
					$statusText->see('end');
					$res = $dB->do($sqlstmt)
							or &show_err(" XEQ ERROR: ".$dB->err.':'.$dB->errstr);
					$sqlstmt = '';
					$stmtcnt++;
				}
			}
			$statusText->insert('end',"..XEQ:  DID $stmtcnt commands.\n");
			$statusText->see('end');
		}
	}
}

sub doUseDB
{
	my $usedb = shift;
	my $usetheme = shift;
	return 0  unless ($usedb);

	my $csr = $dB->prepare("use $usedb") 
			|| &show_err("Could not \"use\" database=$usedb! ".$dB->err.':'.$dB->errstr);
	$csr->execute  
	|| &show_err("could not execute \"use $usedb\": ".$dB->err.':'.$dB->errstr);
	$csr->finish;
	&loadtable;
	&setTheme($usetheme)  if ($usetheme);
	$mainTitle =~ s/ using\:.+$//;
	$mainTitle .= " using:$usedb.";
	$MainWin->title($mainTitle);

}

sub fmtChars
{
	my %specialHash = ("\x07" => '\\a', "\x08" => '\\b', "\x09" => '\\t', 
			"\x0a" => '\\n', "\x0b" => '\\v', "\x0c" => '\\f', 
			"\x0d" => '\\r', "\\" => '\\\\', "\x00" => '\\0');
	my $str = shift;
	$str =~ s/([\x00\x07-\x0d\\])/$specialHash{$1}/g;
	$str =~ s/([\x00-\x1f\x80-\xa0])/sprintf '\\x%02x', ord($1)/eg;
	return $str;
}

__END__
