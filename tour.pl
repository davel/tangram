#!/usr/bin/perl

use strict;

use Tangram;
use Tangram::Deploy;
use Tangram::Springfield;

use DBI;

use Getopt::Std;
my %opt;
getopts('pxt', \%opt);

my @cp = @ARGV;
@cp = qw( dbi:Sybase:database=Springfield tangram tangram ) unless @cp;
my $cp = join(', ', map { "'$_'" } @cp);

my @tour_vars = qw( $schema $dbh $storage @kids $marge $homer $homer_id
	$flanders_id @sisters_id $ned $ned_id @sisters @pairs
	$patty $selma $burns
	);
use vars @tour_vars;

eval
  {
    my $dbh = DBI->connect( @cp ) or die;
    $schema->retreat($dbh);
    $dbh->disconnect();
  } if $opt{x};

my $tour = join '', <DATA>;

if (exists $opt{p} && keys(%opt) == 1)
{
	$tour =~ s/{{\n//gm;
	$tour =~ s/}}\n//gm;
	print $tour;
	exit;
}

$Tangram::TRACE = \*STDOUT if exists $opt{t};

$tour =~ s[\@cp][$cp]g;
$tour =~ s[ {{ (.*?) }} ][ eval "use vars qw( @tour_vars ); $1"; $1 ]smgex if exists $opt{x};
	

__END__
=head1 NAME

Tangram - Orthogonal Object Persistence in Relational Databases

=head1 DESCRIPTION

Tangram is an object-relational mapper. It makes objects persist in
relational databases, and provides powerful facilities for retrieving
and filtering them.  Tangram fully supports object-oriented
programming, including polymorphism, multiple inheritance and
collections.  It does so in an orthogonal fashion, that is, it doesn't
require your classes to implement support functions nor inherit from a
utility class.

=head1 SUPPORTED PLATFORMS

Tangram is known to run in the following environments, however,
Tangram uses standard SQL and should be usable SQL-83 database.

Note that some functions (e.g. transactions and subselects) may not be
available in some environments. This is reported during the test suite.


=over 4

=item *

Perl 5.00503

=item *

Set::Object 1.02

=item *

DBI 1.14

=item *

DBD::mysql 2.0402

=item *

DBD::Oracle 1.06

=item *

DBD::Sybase 0.21

=item *

DBD::Pg 0.93

=back

=head1 GUIDED TOUR

In this tour, we add persistence to a simple Person design.

A Person is either a NaturalPerson or a LegalPerson. Persons (in
general) have a collection of addresses.

An address consists in a type (a string) and a city (also a string).

NaturalPerson - a subclass of Person - represents persons of flesh and
blood. NaturalPersons have a name and a firstName (both strings) and
an age (an integer). NaturalPersons sometimes have a partner (another
NaturalPerson) and even children (a collection of NaturalPersons).

LegalPerson - another subclass of Person - represents companies and
other entities that the law regards as 'persons'. A LegalPerson has a
name (a string) and a manager (a NaturalPerson).

All this is expressed in the following UML diagram:


                       +---------------------+        +--------------+ 
                       |       Person        |        |    Address   |
                       |     { abstract }    |1<>-->-*|--------------|
                       |---------------------|        | type: string |
                       +---------------------+        | city: string |
                                   |                  +--------------+
                                   |
                    +--------------A--------------+
                    |                             |             
          +-------------------+           +---------------+          
      +--*|   NaturalPerson   |           |  LegalPerson  |        
      |   |-------------------|manager    |---------------|
      V   | firstName: string |1---<-----1| name: string  |        
      |   | name: string      |           +---------------+        
      +--*| age: integer      |
 children +-------------------+
                1       1 
                |    partner
                |       |
                +--->---+

B<Note that Tangram does I<not> create the corresponding Perl
packages!>. That's up to the user. However, to facilitate
experimentation, Tangram comes with a module that implements the
necessary classes. For more information see L<Tangram::Springfield>.

Before we can actually store objects we must complete two steps:

=over 4

=item 1

Create a Schema

=item 2

Create a database

=back

=head2 Creating a Schema

A Schema object contains information about the persistent
aspects of a system of classes.

It also gives a degree of control over the way Tangram performs the
object-relational mapping, but in this tour we will use all the defaults.

Here is the Schema for Springfield:
{{
   $schema = Tangram::Schema->new(

      classes =>
      {
        Person =>
        {
		 	abstract => 1,
	   
			fields =>
			{
				iarray =>
				{
					addresses =>
					{
						aggreg => 1
					}
			   }
			}
		},

		Address =>
	 	{
	    	fields =>
	     	{
				string => [ qw( type city ) ],
	     	}
	 	},

		NaturalPerson =>
        {
        	bases => [ qw( Person ) ],

            fields =>
            {
               string   => [ qw( firstName name ) ],
               int      => [ qw( age ) ],
               ref      => [ qw( partner ) ],
               array    => { children => 'NaturalPerson' },
            },
         },

         LegalPerson =>
         {
            bases => [ qw( Person ) ],

            fields =>
            {
               string   => [ qw( name ) ],
               ref      => [ qw( manager ) ],
            },
         },
      } );
}}
The Schema lists all the classes that need persistence, along with
their attributes and the inheritance relationships.  We must provide
type information for the attributes, because SQL is more typed than
Perl.  We also tell Tangram that C<Person> is an abstract class, so it
wastes no time attempting to retrieve objects of that exact class.

Note that Tangram cannot deduce this information by itself. While Perl
makes it possible to extract the list of all the classes in an
application, in general not all classes will need to persist. A class
may have both persistent and non-persistent bases.  As for attributes,
Perl's most typical representation for objects - a hash - even allows
two objects of the same class to have a different set of attributes.

For more information on creating Schemas, see L<Tangram::Schema>.

=head2 Setting up a database

Now we create a database. The simplest way is to create an
empty database and let Tangram initialize it:
{{
	use Tangram;
	use Tangram::Deploy;

	$dbh = DBI->connect(
		@cp ); 	

   	$schema->deploy( $dbh );

	$dbh->disconnect();
}}
For more information on deploying databases, see L<Tangram::Deploy>.

=head2 Connecting to a database

We are now ready to store objects. First we connect to the database,
using the class method Tangram::Relational::connect. Its
first argument is the schema object; the others are passed directly to
DBI::connect. The method returns a Tangram::Storage object that will be
used to communicate with the database.

For example:
{{
   	$storage = Tangram::Relational->connect( $schema,
		@cp );
}}
connects to a database named Springfield via the Sybase driver, using
a specific account and password.

For more information on connecting to databases, see  L<Tangram::Relational> and
L<Tangram::Storage>.

=head2 Inserting objects

Now we can populate the database:
{{
   $storage->insert( NaturalPerson->new(
      firstName => 'Montgomery', name => 'Burns' ) );
}}
This inserts a single NaturalPerson object into the database. We can
insert several objects in one call:
{{
   $storage->insert(
      NaturalPerson->new( firstName => 'Patty', name => 'Bouvier' ),
      NaturalPerson->new( firstName => 'Selma', name => 'Bouvier' ) );
}}
Sometimes Tangram saves objects implicitly:
{{
   	@kids = (
		NaturalPerson->new( firstName => 'Bart', name => 'Simpson' ),
		NaturalPerson->new( firstName => 'Lisa', name => 'Simpson' ) );

   	$marge = NaturalPerson->new(
		firstName => 'Marge', name => 'Simpson',
		addresses => [
			Address->new(
				type => 'residence', city => 'Springfield' ) ],
		children => [ @kids ] );

   	$homer = NaturalPerson->new( firstName => 'Homer', name => 'Simpson',
		addresses => [
			Address->new(
				type => 'residence', city => 'Springfield' ),
			Address->new(
				type => 'work', city => 'Springfield' ) ],
		children => [ @kids ] );

   	$homer->{partner} = $marge;
   	$marge->{partner} = $homer;
   
   	$homer_id = $storage->insert( $homer );
}}
In the process of saving Homer, Tangram detects that it contains
references to objects that are not persistent yet (Marge, the
addresses and the kids), and inserts them automatically. Note that
Tangram can handle cycles: Homer and Marge refer to each other.

insert() returns an object id, or a list of object ids, that uniquely
identify the object(s) that have been inserted.

For more information on inserting objects, see L<Tangram::Storage>.

=head2 Updating objects

Updating works pretty much the same as inserting:
{{
   	my $maggie = NaturalPerson->new( firstName => 'Maggie', name => 'Simpson' );

   	push @{ $homer->{children} }, $maggie;
   	push @{ $marge->{children} }, $maggie;

   	$storage->update( $homer, $marge );
}}
Here again Tangram detects that Maggie is not already persistent in
$storage and automatically inserts it. Note that we need to update
Marge explicitly because she was already persistent.

For more information on updating objects, see L<Tangram::Storage>.

=head2 Memory management

...is still up to you. Tangram won't break in-memory cycles, it's a
persistence tool, not a memory management tool. Let's make sure we
don't leak objects:
{{
   $homer->{partner} = undef; # do this before $homer goes out of scope
}}
Also, when we're finished with a storage, we can explicitly disconnect it:
{{
   $storage->disconnect();
}}
Whether it's important or not to disconnect the Storage depends on
what version of Perl you use. If it's prior to 5.6, you I<must>
disconnect the storage explicitly (or at least call unload())
otherwise the Storage will prevent the objects it controls from being
reclaimed by Perl. For more information see see L<Tangram::Storage>.

=head2 Finding objects

After reconnecting to Springfield, we now want to retrieve some objects.
But how do we find them? Basically there are three options

=over 4

=item *

We know their IDs.

=item *

We obtain them from another object.

=item *

We use a query.

=back

=head2 Loading by ID

When an object is inserted, Tangram assigns an identifier to it.
IDs are numbers that uniquely identify objects in the database.
C<insert> returns the ID(s) of the object(s) it was passed:
{{
   	$storage = Tangram::Storage->connect( $schema,
		@cp );

   	$flanders_id = $storage->insert( NaturalPerson->new(
      	firstNname => 'Ned', name => 'Flanders' ) );

   	@sisters_id = $storage->insert(
      	NaturalPerson->new( firstName => 'Patty', name => 'Bouvier' ),
      	NaturalPerson->new( firstName => 'Selma', name => 'Bouvier' ) );
}}
This enables us to retrieve the objects:
{{
   	$ned = $storage->load( $ned_id );
   	@sisters = $storage->load( @sisters_id );
}}
For more information on loading objects by id, see L<Tangram::Storage>.

=head2 Obtaining objects from other objects

Once Homer has been restored to his previous state, including his relations
with his family. Thus we can say:
{{
   	$storage = Tangram::Storage->connect( $schema,
		@cp );

	$homer = $storage->load( $homer_id ); # load by id

   	$marge = $homer->{partner};
   	@kids = @{ $homer->{children} };
}}
Actually, when Tangram loads an object that contains references to
other persistent objects, it doesn't retrieve the referenced objects
immediately. Marge is retrieved only when Homer's 'partner' field is
accessed.  This mechanism is almost totally transparent, we'd have to
use C<tied> to observe a non-present collection or reference.

For more information on relationships, see L<Tangram::Schema>,
L<Tangram::Ref>, L<Tangram::Array>, L<Tangram::IntrArray>,
L<Tangram::Set> and L<Tangram::IntrSet>.

=head2 select

To retrieve all the objects of a given class, we use C<select>:
{{
   	$storage = Tangram::Storage->connect( $schema,
		@cp );

   	my @people = $storage->select( 'NaturalPerson' );
}}
We can also retrieve tuples of objects:
{{
	my ($parent, $child) = $storage->remote('NaturalPerson', 'NaturalPerson');

	@pairs = $storage->select( [ $parent, $child ],
		$parent->{children}->includes($child) );
}}
@pairs contains a list of references to arrays of size two; each array
contains a pair of parent and child.

For more information on select(), see L<Tangram::Storage>.

=head2 Filtering

Usually we won't want to load I<all> the NaturalPersons, only those
objects that satisfy some condition. Say, for example, that we want to
load only the NaturalPersons whose name field is 'Simpson'. Here's how
this can be done:
{{
   	my $person = $storage->remote( 'NaturalPerson' );
   	my @simpsons = $storage->select( $person, $person->{name} eq 'Simpson' );
}}
This will bring in memory only the Simpsons; Burns or the Bouvier
sisters won't turn up.  The filtering happens on the database server
side, not in Perl space. Internally, Tangram translates the
C<$person->{name} eq 'Simpson'> clause into a piece of SQL code that
is passed down to the database.

The above example only begins to scratch the surface of Tangram's
filtering capabilities. The following examples are all legal and working code:
{{
	# find all the persons *not* named Simpson

   	my $person = $storage->remote( 'NaturalPerson' );
   	my @others = $storage->select( $person, $person->{name} ne 'Simpson' );

   	# same thing in a different way

   	my $person = $storage->remote( 'NaturalPerson' );
   	my @others = $storage->select( $person, !($person->{name} eq 'Simpson') );

   	# find all the persons who are older than me

	my $person = $storage->remote( 'NaturalPerson' );
   	my @elders = $storage->select( $person, $person->{age} > 35 );

   	# find all the Simpsons older than me

   	my $person = $storage->remote( 'NaturalPerson' );
   	my @simpsons = $storage->select( $person,
   	   	$person->{name} eq 'Simpson' & $person->{age} > 35 );

   	# find Homer's wife - note that select *must* be called in list context

   	my ($person1, $person2) = $storage->remote(
		qw( NaturalPerson NaturalPerson ));

   	my ($marge) = $storage->select( $person1,
      	$person1->{partner} == $person2
      	& $person2->{firstName} eq 'Homer' & $person2->{name} eq 'Simpson' );

   	# find Homer's wife - this time Homer is already in memory

   	my $homer = $storage->load( $homer_id );
   	my $person = $storage->remote( 'NaturalPerson' );

   	my ($marge) = $storage->select( $person,
      	$person->{partner} == $homer );

   	# find everybody who works in Springfield

   	my $address = $storage->remote( 'Address' );

   	my @population = $storage->select( $person,
      	$person->{addresses}->includes( $address )
		& $address->{type} eq 'work'
		& $address->{city} eq 'Springfield

   	# find the parents of Bart Simpson

   	my ($person1, $person2) = $storage->remote(
		qw( NaturalPerson NaturalPerson ));

   	my (@parents) = $storage->select( $person1,
      	$person1->{children}->includes( $person2 )
      	& $person2->{firstName} eq 'Bart' & $person2->{name} eq 'Simpson' );

   	# find the parents of Bart Simpson - he's already loaded

   	my $bart = $storage->load( $bart_id );
   	my $person = $storage->remote( 'NaturalPerson' );

   	my (@parents) = $storage->select( $person,
      	$person->{children}->includes( $bart ) );
}}
Note that Tangram uses a single ampersand (&) or vertical bar (|) to
represent logical conjunction or disjunction, not the usual && or
||. This is due to a limitation in Perl's operator overloading
mechanism. Make sure you never forget this, because, unfortunately,
using && or || in place of & or | is not even a syntax error :(

For more information on filters, see L<Tangram::Expr> and L<Tangram::Remote>.

=head2 Cursors

Cursors provide a way of retrieving objects one at a time.  This is
important is the result set is potentially large.  cursor() takes the
same arguments as select() and returns a Cursor objects that can be
used to iterate over the result set via methods current() and next():
{{
   	$storage = Tangram::Storage->connect( $schema,
		@cp );

   	# iterate over all the NaturalPersons in storage

   	my $cursor = $storage->cursor( 'NaturalPerson' );

   	while (my $person = $cursor->current())
   	{
		# process $person
		$cursor->next();
   	}

   	$cursor->close();
}}
The Cursor will be automatically closed when $cursor is garbage-collected,
but Perl doesn't define just when that may happen :( Thus it's a good idea to
explicitly close the cursor.

Each Cursor uses a separate connection to the database. Consequently you can
have several cursors open at the same, all with pending results. Of course,
mixing reads and writes to the same tables can result in deadlocks.

For more information on cursors, see L<Tangram::Storage> and
L<Tangram::Cursor>.

=head2 Remote objects

At this point, most people wonder what $person I<exactly> is and how
it all works.  This section attempts to give an idea of the mechanisms
that are used.

In Tangram terminology, $person a I<remote> object. Its Perl class is
Tangram::Remote, but it's really a placeholder for an object of class
C<NaturalPerson> I<in the database>, much like a table alias in
SQL-speak.

When you request a remote object of a given class, Tangram arranges
that the remote object I<looks like> an object of the said class. It
I<seems> to have the same fields as a regular object, but don't be
misled, it's not the real thing, it's just a way of providing a nice
syntax.

If you dig it, you'll find out that a Remote is just a hash of
Tangram::Expr objects.  When you say $homer->{name}, an Expr is
returned, which, most of the time, can be used like any ordinary Perl
scalar. However, an Expr represents a value I<in the database>, it's
the equivalent of Remote, only for expressions, not for objects.

Expr objects that represent scalar values (e.g. ints, floats, strings)
can be compared between them, or compared with straight Perl
scalars. Reference-like Exprs can be compared between themselves and
with references

Expr objects that represent collections have an C<include> methods
that take a persistent object, a Remote object or an ID.

The result of comparing Exprs (or calling C<include>) is a
Tangram::Filter that will translate into part of the SQL where-clause
that will be passed to the RDBMS.

For more information on remote objects, see L<Tangram::Remote>.

=head2 Multiple loads

What happens when we load the same object twice? Consider:
{{
   	my $person = $storage->remote( 'NaturalPerson' );
   	my @simpsons = $storage->select( $person, $person->{name} eq 'Simpson' );

   	my @people = $storage->select( 'NaturalPerson' );
}}
Obviously Homer Simpson will be retrieved by both selects. Are there
two Homers in memory now? Fortunately not. There is only one copy of
Homer in memory. When Tangram load an object, it checks whether an
object with the same ID is alredy present. If yes, it keeps the old
copy, which is desirable, since we may have changed it already.

Incidentally, this explains why a Storage will hold objects in memory
- until disconnected (again, this will change when Perl supports weak
references).

=head2 Transactions

Tangram wraps database transactions in a object-oriented interface:

   	$storage->tx_start();
   	$homer->{partner} = $marge;
   	$marge->{partner} = $homer;
   	$storage->update( $homer, $marge );
   	$storage->tx_commit();

Both Marge and Homer will be updated, or none will. tx_rollback() drops
the changes.

Tangram does not emulate transactions fo rdatabases that do not
support them (like earlier versions of mySql).

Unlike DBI, Tangram allows the nested transactions:

   	$storage->tx_start();

   	{
      	$storage->tx_start();
      	$patty->{partner} = $selma;
      	$selma->{partner} = $patty;
      	$storage->tx_commit();
   	}

   	$homer->{partner} = $marge;
   	$marge->{partner} = $homer;
   	$storage->update( $homer, $marge );

   	$storage->tx_commit();

Tangram uses a single database transaction, but commits it only when
the tx_commit()s exactly balance the tx_start()s. Thanks to this
feature any piece of code can open all the transactions it needs and
still cooperate smoothly with the rest of the application.  If a DBI
transaction is already active, it will be reused; otherwise a new one
will be started.

Tangram offer a more robust alternative to the start/commit code
sandwich.  tx_do() calls CODEREF in a transaction. If the CODEREF
dies, the transaction is rolled back; otherwise it's committed.  The
first example can be rewritten:

	$storage->tx_do( sub {
		$homer->{partner} = $marge;
		$marge->{partner} = $homer;
		$storage->update( $homer, $marge };
		} );

For more information on remote objects, see L<Tangram::Storage>.

=head2 Polymorphism

Up to now we've always used NaturalPerson. However, everything we've
seen thus far also works in presence of polymorphism. Let's create a
LegalPerson:
{{
   	$storage->insert( LegalPerson->new(
      	name => 'Springfield Nuclear Power Plant', manager => $burns ) );
}}
we now have two kinds of Person objects in the storage: Natural- and
LegalPersons. If we select all the Persons:
{{
   	my @all = $storage->select( 'Person' );
}}
...Tangram does what you would expect: it retrieves Homer and all the
other persons of flesh and blood I<and> the Nuclear Power Plant.

=head1 LICENSE & WARRANTY

Tangram is free software. You may use, modify and redistribute this
module under the same terms as Perl itself.

TANGRAM COMES WITHOUT ANY WARRANTY OF ANY KIND.

=head1 SUPPORT

Please send bug reports directly to me (jll@tangram-persistence.org)
or to the Tangram mailing list (tangram-users@lists.sourceforge.net).

Whenever possible, join a short, complete script demonstrating the
problem.

Questions of general interest should should be posted either to the
mailing list or to comp.lang.perl.modules, which I monitor daily. Make
sure to include 'Tangram' in the subject line.

Commercial support for Tangram is available. Visit the Tangram website
(www.tangram-persistence.org) for support options or contact me
at jll@skynet.be.

=head1 ACKNOWLEDGEMENTS

I'd like to thank all the people that have helped me build Tangram by
contributing code, testing, sending bug reports and remarks.

=head1 AUTHOR

Jean-Louis Leroy, jll@tangram-persistence.org

=head1 SEE ALSO

perl(1), DBI, overload, Set::Object.

=cut