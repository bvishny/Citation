Citation
========

DESCRIPTION:
This is code from a few summers ago when a Finance professor hired me for his project to change Academic Citation ranking software. My job was to crawl nearly a million pages on online journal sites to retrieve a complete list of articles and their authors. I focused my work on large sites such as ScienceDirect, SpringerLink, and Blackwell because they house the great majority of the journals. I ran about 50 workers on Rackspace cloud servers (at the time it was better for our purposes than AWS), each which accepted crawling tasks from the main server. Those workers would then batch out to the TokyoTyrant instance to store the data collected.

HIGHLIGHTS:
dependencies_tokyo/tokyo_record.rb - a ActiveRecord-like interface for TokyoTyrant
dependencies_tokyo/indexers_tokyo/* - scraping code for each site enscapulated into a common interface
