# Backup files via (L)FTP and MySQL

* LFTP support only
* MySQL via remote dump (see Credits)
* Exclude multiple files / folders
* Exclude by glob
* Send mail when done

## Installation
* Install LFTP
* Clone / copy the repository
* chmod u+x backup.sh

## Usage

### Configurations
* Create a folder, e.g.: `configs`
* Copy `etc/_config.sample.x` and edit to your needs

**If you don't want a backup to happen prefix it with `_`**

### Options
```
--config   Config files, glob expression allowed
--test     Make a test run - quits file sync after 5 seconds. Allowed values: '1'
```

### Single backup
```
./backup.sh --config "config/your_config.x"
```

### Single backup - test run
```
./backup.sh --config "config/your_config.x" --test 1
```

### Multiple backups
```
./backup.sh --config "config/*.x"
```

## Future
* ZIP it

## Contributing
1. Fork it!
2. Create your feature branch: `git checkout -b my-new-feature`
3. Commit your changes: `git commit -am 'Add some feature'`
4. Push to the branch: `git push origin my-new-feature`
5. Submit a pull request :D

## Credits
[MYSQL-dump PHP](https://github.com/dg/MySQL-dump) package by David Grudl

## License
TODO: Write license
