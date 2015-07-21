# pubOTDR: a simple OTDR SOR file parser

The SOR ("Standard OTDR Record") data format is used to store OTDR 
([optical time-domain
reflectometer](http://https://en.wikipedia.org/wiki/Optical_time-domain_reflectometer)
) fiber data.  The format is defined by the Telcordia [SR-4731, issue
2](http://telecom-info.telcordia.com/site-cgi/ido/docs.cgi?ID=SEARCH&DOCUMENT=SR-4731&)
standard.  While it is a standard, it is unfortunately not open, in
that the specifics of the data format are not openly available.  You
can buy the standards document from Telcordia for $750 US (as of this
writing), but this was too much for my budget. (And likely comes with
all sorts of licensing restrictions. I wouldn't know; I have never
seen the document!)


There are several freely available OTDR trace readers available for
download on the web, but most do not allow exporting the trace data
into, say, a CSV file for further analysis, and only one that I've
found that run on Linux (but without source code.  Some of these do
work in the Wine emulator however).  There have been requests on
various Internet forums asking for information on how to extract the
trace data, but I am not aware of anyone providing any answers beyond
pointing to the free readers and the Telcordia standard.


Fortunately the data format is not particularly hard to decipher.  The
table of contents on the Telcordia [SR-4731, issue
2](http://telecom-info.telcordia.com/site-cgi/ido/docs.cgi?ID=SEARCH&DOCUMENT=SR-4731&)
page provides several clues, as does the Wikipedia page on [optical
time-domain
reflectometer](http://https://en.wikipedia.org/wiki/Optical_time-domain_reflectometer).


Using a binary-file editor/viewer and comparing the outputs from
some free OTDR SOR file readers, I was able to piece together most of
the encoding in the SOR data format and written a simple program (in
Perl) that parses the SOR file and dumps the trace data into a file.
Presented here for your entertainment are my findings, in the hope
that it will be useful to other people.  But **use it at your own
risk!** The information provided here is based on guess work from
looking at a limited number of sample files.  I can not guarantee that
there are no mistakes, or that I have uncovered all possible
exceptions to the rules that I have deduced from the sample files.
*You have been warned!*




