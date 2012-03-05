# MySQL Replication Diagram Tool

## ring_graph.pl
A simple perl/GraphViz tool to build a replication diagram for a given set of MySQL servers.
Currently intended to be run out of cron and spitting out png files to be dumped somewhere http accessible

### Usage
todo

### Installation - RedHat/CentOS/Oracle Linux
 
	# install dependcies from the el5 repo 
	yum install perl-GraphViz graphviz-gd perl-YAML perl-File-Slurp
	# CPAN in YAML::AppConfig
	perl -MCPAN -e 'install YAML::AppConfig'

### History
Original concept by Simon McCartney, tidy up by Patrick Galbraith (http://patg.net/)
(Lots of inspiration from John Woffindin, http://facebook.com/jwoffindin, from his GCRT tool)
