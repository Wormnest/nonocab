#!python

import os
import re
import datetime

# ----------------------------------
# Definitions:
# ----------------------------------

# AI name
ai_name = "NoNoCAB"
ai_pack_name = ai_name.replace(" ", "-")

# ----------------------------------
version_file = "../version.nut";

# We want the date to be updated before releasing the tar
# and the version number to be updated after updating
# Thus we can't do it at the same time.
version = -1
found_line = 0
date_line = 0
cur_line = 0

# Open version file for reading and writing (r+)
ver_file = open(version_file, "r+");
lines = ver_file.readlines();
ver_file.seek(0);
#ver_file.truncate();
for i, line in enumerate(lines):
    cur_line += 1;
    r = re.search('SELF_VERSION\s+<-\s+([0-9]+)', line)
    if (r != None):
        version = r.group(1)
        found_line = cur_line
        ver_file.write(line);
    else:
        r = re.search('SELF_DATE\s+<-\s+\"([0-9\-]+)\"', line)
        if (r != None):
            date_line = cur_line
            now = datetime.date.today();
            ver_file.write('SELF_DATE <- "{0}-{1:02}-{2:02}";'.format(now.year, now.month, now.day));
        else:
            ver_file.write(line);
# Write empty line at the end
ver_file.write("\n");
ver_file.close();

if(version == -1):
    print("Couldn't find " + ai_name + " version in info.nut!")
    exit(-1)

base_dir_name = ai_pack_name + "-v" + version
temp_dir_name = "..\\..\\temp"
releases_dir = "..\\..\\nonocab-releases\\"
dir_name =  temp_dir_name + "\\" + base_dir_name
tar_name = base_dir_name + ".tar"

# Linux commands:
#os.system("mkdir " + dir_name);
#os.system("cp -Ra *.nut lang " + dir_name);
#os.system("tar -cf " + tar_name + " " + dir_name);
#os.system("rm -r " + dir_name);


# ----------------------------------------------------------------
# Experimental TODO: try to make the tar from inside python
# See: http://stackoverflow.com/questions/2032403/how-to-create-full-compressed-tar-file-using-python
# See: http://docs.python.org/2/library/tarfile.html#tarfile.TarFile.add
import tarfile

#To build a .tar.gz for an entire directory tree:
def make_tarfile(output_filename, source_dir):
    # Mode w = uncompressed writing
    with tarfile.open(output_filename, "w") as tar:
        tar.add(source_dir, arcname=os.path.basename(source_dir))

# ----------------------------------------------------------------
# Windows
# Copies all files and non empty folders except the files/folders excluded in exclude.exc
os.system("xcopy ..\\*.* " + dir_name + "\\ /S /EXCLUDE:exclude.exc");

# Now tar the folder we just made
# Since cd doesn't seem to work here we will do it in a batch file
os.system("run_tar.bat " + tar_name + " " + base_dir_name)

# Now copy it to our WormAI\releases folder...
os.system("xcopy " + temp_dir_name + "\\" + tar_name + " " + releases_dir);
os.system("del " + temp_dir_name + "\\" + tar_name)


# Finally we want to update our version number
# Can't open it both for reading and writing, or need different parameter, not bothering to 
# look into it now just open it twice
version_nut = open(version_file);
lines = version_nut.readlines();
version_nut.close();

#Now open for writing
version_nut = open(version_file, "wt");

# Write all lines
for i, line in enumerate(lines):
    if found_line == i+1:
        # Replace string version number with increased version number
        version = int(version) + 1;
        version_nut.write("SELF_VERSION <- {0};\n" .format(version));
    else:
        # Rewrite the line
        version_nut.write(line);
#    print(str(i) + "  " + line);

version_nut.close();
