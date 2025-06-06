#############################################################################
#                                                                           #
#            PerLDAP v1.0 - A Perl Developers' Kit for LDAP                 #
#                                                                           #
#############################################################################


What is PerLDAP?
================

PerLDAP is a set of modules written in Perl and C that allow developers to
leverage their existing Perl knowledge to easily access and manage LDAP-
enabled directories.  PerLDAP makes it very easy to search, add, delete,
and modify directory entries.  For example, Perl developers can easily
build web applications to access information stored in a directory or
create directory sync tools between directories and other services.

PerLDAP is an open source development project, the result of a joint effort
between Netscape and Clayton Donley, an open source developer.  PerLDAP
currently provides the basic functions to allow Perl users to access and
manipulate directories easily.  Based on developer feedback and
involvement, PerLDAP will continue to evolve to include additional
functionality in future releases.


Installing PerLDAP Binaries
===========================

You will first need version 3.0 Beta 1 of the LDAP C SDK from Netscape.  This
is available from the DevEdge page at:

    http://developer.netscape.com/tech/directory/

You will also need Perl v5.004, available at http://www.perl.com/. Version
5.005 of Perl will NOT work with the binaries.  If you wish to use v5.005,
you will need to compile PerLDAP from source.

On Unix (Solaris Only...HPUX, IRIX, AIX to follow):
  1. Be sure that the libraries from the C SDK are installed in locations
     referenced by the environment variable LD_LIBRARY_PATH.
  2. Save the file in a temporary location
  3. Unzip the file by entering the command:
      gunzip <filename>.tar.gz
  4. Untar the resulting tar file by entering the command:
      tar xvof <filename>.tar
  5. Change to the extract directory:
      cd PerLDAP-1.0
  6. Execute the following command in as the super-user (root):
      perl install-bin

On Windows NT:
  1. Be sure that the DLL from the C SDK is installed in your system32
     directory.
  2. Save the file in a temporary location
  3. Unzip the file using Winzip or other ZIP extraction tools
  4. Change to the extract directory:
      cd PerLDAP-1.0
  5. Execute the following command:
      perl install-bin


Compiling the PerLDAP Sources
=============================

The source to PerLDAP is available on the Mozilla site at:

  http://www.mozilla.org/directory/

You can either retrieve the .tar file with the source distribution, or use
CVS to checkout the module directly. The name of the CVS module is
PerLDAP, and it checks out the directory

  mozilla/directory/perldap

Further instructions for using CVS and Mozilla is available at

  http://www.mozilla.org/cvs.html

Instructions for building the source can be found in the INSTALL file
in the source distribution.


Getting Started
===============

Documentation for this module is in standard Perl 'pod' format.  HTML
versions of this documentation can also be found on the Netscape DevEdge
site at:  http://developer.netscape.com/tech/directory/.

Additionally, many good examples can be found in the 'examples' directory.


Modules and Examples Included
=============================

Mozilla::LDAP::API - Low level interface between Perl and the LDAP C API
Mozilla::LDAP::Entry - Perl methods for manipulating entry objects
Mozilla::LDAP::Conn - Perl methods for performing LDAP operations
Mozilla::LDAP::LDIF - Perl methods for utilizing LDIF
Mozilla::LDAP::Utils - Some convenient LDAP related utilities
test_api/search.pl - Tests low level API search calls
test_api/write.pl  - Tests low level API write calls
test_api/api.pl - Tests ALL low level LDAPv2 calls
examples/lfinger.pl - LDAP version of the regular Unix finger command.
examples/qsearch.pl - Simple ldapsearch replacement.
examples/monitor.pl - Retrieve status information from an LDAP server.
examples/ldappasswd.pl - Change the LDAP password for a user.
examples/rmentry.pl - Remove an entire entry from the database.
examples/rename.pl - Rename (modRDN) an entry.
examples/tabdump.pl - Dump LDAP information into a tab separated file.
examples/psoftsync.pl - Synchronize LDAP with a PeopleSoft "dump" file.


All examples support the "standard" LDAP command line options, which are

        -h hostname     LDAP server name
        -p port #       LDAP port, default is 389 (or 636 for SSL)
        -b base DN      LDAP Base-DN
        -D bind DN      LDAP bind DN (connect to server as this "user")
        -w bind pswd    Password to bind to the server
        -P certfile     Use SSL, with the publick keys from this file


Note that the examples currently only support Simple Authentication
(passwords), the Client Authentication features (using certificates) will
be used in the next release. All examples also honors the environment
variable LDAP_BASEDN, set it to your systems base DN, e.g.

        % setenv LDAP_BASEDN 'dc=netscape,dc=com'

or for Bourne shell

        # LDAP_BASEDN='dc=netscape,dc=com'; export LDAP_BASEDN


Reporting problems and bugs
===========================

Address all bug reports and comments to the Mozilla newsgroups at:

   news://news.mozilla.org/netscape.public.mozilla.general


License/Copyright
=================

Portions by Netscape (c) Copyright 1998 Netscape Communications Corp, Inc.
Portions by Clayton Donley (c) Copyright 1998 Clayton Donley

Please read the MPL-1.0.txt file included for information on the Mozilla
Public License, which covers all files in this distribution.

Known Bugs
==========

There are a number of issues still outstanding at the time of release.  Most
of these are already in the process of being resolved.

 - There is a possible memory leak in the search routines. The OO layer
   is also more memory than it should.
 - The Rebind operation on NT does NOT work properly when set to a Perl
   function.  This is being investigated.
 - Some of the documentation is incomplete.
