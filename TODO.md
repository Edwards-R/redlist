Next task is buffer-union
    at 10km
    at 2km

Need to work out if the best approach is to save down or not. Maybe? Not sure. Need to check the mapping program to see how it would fit in

Ideally create a procedure to create a buffer-union table. This would mean that making buffer-union slices is a function call not a complex query
Simple means I can do moving averages etc.

Maybe make factory functions that produce e.g. 3 x 10 year ending in 2021     or  N x M year, with X overlap, ending in Y year or something

Probably two procedures for that, way too complex to try and do in one at first 



### MAKING BUFFER UNION FAST(er)

* Step 1: make view for annual unique per taxa
* Step 2: ???
* Step 3: Make final view

This strikes a compromise between speed and flexibility, and will work nicely with the mapper