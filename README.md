Kōfu: Mining Travis-CI dataset

Just run the script

```
$ ruby kofu.rb process -f data.csv 
```

If you want to see the collected patterns, then use the following command

```
$ ruby kofu.rb process -f data.csv -p
```

Notes: please unzip the file 'data.csv.zip' before running kofu.rb 

Supported commands:

```
› ruby kofu.rb process [OPTIONS]

OPTIONS
    -f, --file FILE                  the csv file to process
    -p, --patterns                   disclose build attempt patterns
    -h, --help                       help
```
