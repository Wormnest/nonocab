cd ..\..\temp
d:\msys64\usr\bin\tar -cf "%1" "%2"
del /Q /S "%2" 
rmdir /S /Q "%2"
