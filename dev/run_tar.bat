cd ..\..\temp
e:\MinGW\msys\1.0\bin\tar -cf "%1" "%2"
del /Q /S "%2" 
rmdir /S /Q "%2"
