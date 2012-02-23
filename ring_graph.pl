#!/usr/bin/perl
#
# Build a topology diagram of our MySQL replication loops

use strict;
use GraphViz;
use DBI;
use YAML::AppConfig;
use File::Slurp;
use Data::Dumper;

my $ymlcnf = read_file('ring.cnf') ;
my $cnf = YAML::AppConfig->new(string => $ymlcnf);

use Getopt::Long;

# Colour Coding: key = host regex, value fillcolor, in X11 color:
# http://en.wikipedia.org/wiki/X11_color_names
my $hosts = $cnf->get_hosts();
my $DB_USER = $cnf->get_username(); 
my $DB_PASSWORD = $cnf->get_password(); 
my $imagedir = $cnf->get_imagedir(); 
my $layout = $cnf->get_layout();
my $layout ||= 'neato';

GetOptions( "layout=s"      => \$layout,
       	    "imagedir=s"    => \$imagedir);

#################################################################
#
#  get_master() 
#
#	Get the slaves master host/IP and report the number of 
#	seconds lagging
# 
#	arguments: 
#		$slave - scalar ref , slave host name or IP
#		$master - scalar ref, for storing master host name or IP
#		$behind_by - scalar ref, for storing seconds behind lag
#
# 	returns:
#		arguments obtain values by reference
#
#################################################################
sub get_master($$$) {
    # deal with the arguments
    my ($slave, $master, $behind_by) = @_;  

    # Find the master for a given host, return the master name as a string
    my $dsn = "DBI:mysql:database=information_schema;host=$$slave";
    my $dbh = DBI->connect($dsn, $DB_USER, $DB_PASSWORD)
        		or return ('failed', $slave);

    my $sth = $dbh->prepare("SHOW SLAVE STATUS");

    $sth->execute;

    if (my $ref = $sth->fetchrow_hashref()) {
    	# Something valid returned!
        $$master 	= $ref->{'Master_Host'};
        $$behind_by 	= $ref->{'Seconds_Behind_Master'};

        $$behind_by = 'NULL' if ($$behind_by =~ /^$/);

        print "\nMaster: $$master, Slave: $$slave, Slave is behind by: $$behind_by\n";
    }
    else {
    # Bad stuff happened
        $$master = 'unknown';
    }
    $sth->finish();
    $dbh->disconnect();

}

my $hosts_to_process = {};
my @zeros;
push(@zeros,0) for keys %$hosts;
@{$hosts_to_process}{keys %$hosts} = @zeros;

# create a new graph image
my $t = GraphViz->new(  layout  => $layout, 
                        width   => 10, 
                        height  => 6,
                        overlap => 'false');

my $unprocessed_items = 0;
for my $host (keys %$hosts_to_process) {
    $unprocessed_items = 1 if ($hosts_to_process->{$host} == 0);
}

my ($master, $behind_by) = ('', '');

while ($unprocessed_items)
{
    # loop through all the hosts, adding masters while looping
    for my $host (keys %$hosts_to_process) {
        if ($hosts_to_process->{$host} == 0) {
            if ($host eq 'unknown') { 
                print "Skipping";
            }
            else {
                my $slave = $host;
                get_master(\$slave, \$master, \$behind_by);

                # add the data to the diagram
                $t->add_node(   $master,
				style 		=> 'filled',
				fillcolor 	=> $hosts->{$master});
                $t->add_node(	$slave, 
				style 		=> 'filled',
				fillcolor 	=> $hosts->{$slave});

                # We don't really care about anyting less than X
                if (($behind_by > 30) && ($behind_by < 60)) {

                    $t->add_edge(   $master     => $slave, 
                                    label       => $behind_by, 
                                    fontcolor   => 'yellow',
                                    style       => 'bold',
                                    color       => 'yellow');
                }
                elsif (($behind_by >= 60) || ($behind_by eq 'NULL')) {

                    $t->add_edge(   $master     => $slave, 
                                    label       => $behind_by,
                                    fontcolor   => 'red',
                                    style       => 'bold',
                                    color       => 'red');
                }
                else {
                    $behind_by = '';
                    $t->add_edge($master => $slave, label => $behind_by);
                }

            }

            $hosts_to_process->{$host} = 1;

            # Do we need to add the master to the work stack?
            if (!exists $hosts_to_process->{$master}) {
                print "\nAdding found host: $master\n";
		        # this is temporary 
                $hosts_to_process->{$master} = 0;
            }
        }

        # Cycle through our list of hosts and see if we need 
        # to do another pass
        $unprocessed_items = 0;
        for my $host (keys %$hosts_to_process) {
            $unprocessed_items = 1 if ($hosts_to_process->{$host} == 0);
        }
    }
}

my $datestamp = localtime();
print "\nCompleted at $datestamp\n";
$t->add_node($datestamp, shape => 'box');

my $filename = sprintf("topology-dbhosts-%s-colour", $layout);
my $fullpath = "$imagedir/$filename.png";

print "Generating $fullpath\n";

open(PNG, ">$fullpath");
print PNG $t->as_png;
close(PNG);
