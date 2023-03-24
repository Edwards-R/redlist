# **Redlist data preparation**

This section outlines the process by which data is filtered before arriving as part of the Redlist, as well as the processes used to generate data for direct mapping, cell occupancy, and buffer_union models

## **Import process**

The steps taken before data reaches the database

### **Sourcing data: BWARS**

The foundation of the Redlist assessment is from the UK's Bees Wasps and Ants Recording Society (BWARS). More information, including the license which data is submitted to BWARS under, can be found on BWARS at their website: https://www.bwars.com/ .

The BWARS data is a crowd-sourced repository with expert-gated submission. Various subject experts have the ultimate say on whether a data set is overall considered credible, meaning that it can start the import process.

### **Data collection**

Data is collected from many sources and styles. All data must be considered to be above a certain level of entomological accuracy i.e. that determinations to species level are made accurately and that the determinations stand up to scrutiny. Data attributes **must** include the following:

* Taxonomic identifier
* OS Grid Reference
* Date of observation

Other fields are encouraged, such as 'collector' and 'determiner'

Notably, there is **no** standardised sampling protocol to generate 'BWARS' data. Nor are there any surveyors directed or in any way guided by BWARS with the purpose of gathering information. Surveying for Aculeate Hymenoptera is a **highly** resource and expertise intensive task, where the role of the BWARS database is to aggregate as much data as possible without comprimising on accuracy.


### **Submission to BWARS**

Data is submitted to BWARS under a crowd-sourcing license, which lays out the conditions by which BWARS can use the data. Submission and formatting is done under the provision that, as BWARS does not actively source data, BWARS carries the responsibility for processing data from the point and format of origin right up to the point of incorporation with the main database. Data typically arrives with BWARS as a .xls, .xlsx, .tab, or .csv file

### **The Checker**

The first post-collection step to data import is to load the provided file into 'The Checker'. This is a pseudo-application written in Filemaker, a hybrid application/database graphical interface program, which was chosen many years ago as a database program which did not require the end user to have a degree to understand. In this application, the attributes of the input file are first matched up to the input fields in the application and then imported. Where a field is not present in the application, it typically is redirect to 'Additional Information' fields so as not to lose that data.

Once the attributes are matched and the data imported, the next step is to perform 'Pre-Processing' scripts. These are scripts which specifically *are* allowed to modify the input data, in order to do things like

* Trim inputs to remove leading/trailing spaces
* Assemble separate date components into a single date field

The number of things that the Pre-Process script is allowed to do is strictly controlled so as to not be able to change the meaning of the input data. The Checker is specifically coded in such a way that it *cannot* make decisions, it can only process what it has. If there arises a situation in which a decision must be made, the script will process the record as far as it can and then alert the user. For example, a record of 'Andrena scotica', which has significant nomenclatural confusion, cannot be assigned an interpretation of A. scotica by the script. Instead, the specific rule which checks the assignment of a binomial to a nomenclatural will fail, write a message in the log, then refuse to pass the record. The human user is then responsible for interpreting the pure binomial into a nomenclatural form.

Following the Pre-Process script, the user elects to run the 'Process' script. This script is responsible for transcribing data from the input fields to the output fields, then working out if the transcribed data is enough to permit the record to enter the main system. Notably, this includes:

* An assigned nomenclatural understanding
* An accepted, land-inclusive grid reference
* A lower and upper bounded date pair

Other fields are filled in as possible. The last important part of processing is to note that the nomenclatural understanding used is the one which represents, as closely as possible, the intent of the submitter of that data point rather than the current interpretation of said understanding. Converting names to their currently understood interpretation is a job for the nomenclatural system, not for data input.

The final action of the Checker is to output the records which have passed the Checker, known as 'the passes' to what Filemaker calls a 'merge' file. This is, in reality, a rather poorly formatted .csv file, but not as poorly formatted as Filemaker's '.csv' format.


### **Postgres**

The second stage of processing is within the BWARS Postgres+PostGIS database. This starts with the import of data to postgres via `pg_import`. Once data is imported, it is converted into the appropriate types (int, string, date etc) and placed in `clone_check`. Grid references are also converted to Easting/Northing/Accuracy/Datum (ENAD). From here, a materialized view is created, called `clone_mat`, which removes all records which have a match in the main database based on:

 * TIK (the numerical keys for nomenclatural understandings)
 * Exact date bounds
 * Exact spatial position based on ENAD

The removal of duplicates at this point is an integral part of preventing pseudo-replication flooding the server. Pseudo-replication is when multiple occurrences of the same record appear, which most frequently occurs when recorders re-submit their entire database of data, with some people doing this four or five times to date. Without a way to handle pseudo-replication, the majority of records in the system very quickly become replicates, slowing down the system whilst providing no valuable response. Eventually, such a system will grind to a hald and be practically non-functional due to slowdown.

Once duplication between the main dataset and the imported dataset has been removed, the spatial and temporal distribution of the import is assessed. These checks examine the placement of each record in relation to its peers - records of the same taxon in a similar spatial timeframe.

The spatial timeframe is determined by the spread in years, starting at the date of the record, which must be used in order to accumulate 200 records of that taxon. There is a minimum spread of +/- 1 year to smooth out recorder bias in the more common taxa.

All non-suspended records of the target taxa within the target year range and then mapped at 10 km resolution, then given a 50 km buffer. If an incoming record is not within this spatial range, it is not automatically passed through the system and must be manually passed.

For temporal information, the taxa/year range looks for the minimum and maximum day of year (doy) range. If the input record is within these bounds, the record is automatically accepted. If not, it must be manually passed. This has specifically been useful in identifying records sourced from rearing.

Finally, the valid input data is then examined for the level of self-replication within the valid input. Anything below 20% self-replication i.e. 20% of the records are duplicates on

 * TIK (the numerical keys for nomenclatural understandings)
 * Exact date bounds
 * Exact spatial position based on ENAD
 * Location, as text
 * Collector, as text

If the level of self-replication is greater than or equal to 20%, the automatic system will not pass the data. This is once again to prevent pseudo-replication from entering the system.

If the imported dataset has reached this point, it is imported into the live database. Any records which have failed due to temporal or spatial checks are retained in the `failure` table, which can be examined by an expert for records which 'true' outliers, which records need further verification, and which records can be ignored. This is done by noting down the unique IDs of the records to pass, which can then be 'recycled' from `failure` into `clone_check` (making sure that the record passes on **both** spatial *and* temporal). From here, records can be directly entered without calling the spatial or temporal checks since these have been manually performed.

### **Cloning BWARS**

There are a number of data sources which were provided for use in the Redlist project which were not to be incorporated into the BWARS database. The simplest method of handling these records is to complete all imports to the BWARS database, then clone the full database into a separate repository. This repository is automatically secured by Postgres and carries over the import routines. Non-BWARS data can then be imported using the Checker and Postgres routines outlined above.

## **Output Preparation**

### **Simple Unique Record**

The final step is to create a view into the main database which:

* Strips out any suspended records
* Resolves nomenclature to the current understanding of the input
* Converts ENAD to OS Grid Reference
* De-duplicates based on
    * Resoved nomenclature
    * Exact ENAD (i.e. spatial position)
    * Lower & upper date

This is the export which is typically used to provide exports. A materialised version can be created in order to speed up rate of access, which is known as `sur_mat` - Simple Unique Record Materialised.

### **Simple Unique Record at 10 km resolution**

Another materialised view created is `sur_mat_10`, which replicates `sur_mat` except that records are converted to a spatial resolution of 10 km and postGIS polygons are created from the 10 km resolution data. This is done to enable visual examination of the placement of specific records within QGIS, which is able to directly read data from this table.

### **Count Cell**