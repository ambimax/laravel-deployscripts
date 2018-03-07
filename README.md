# Laravel Deploy Scripts

Scripts to deploy laravel projects


## How it works

1) Whole laravel project is packaged into a build archive (project.tar.gz)

2) Generated build is copied to a central storage server (s3)

3) Jenkins clones deploy script repo to remote server

4) deploy.sh is executed on remote server and initiates install.sh

5) cleanup script is executed on remote server


### composer
```
"require": {
    "ambimax/laravel-deployscripts": "^1.0"
}
```

## License

[MIT License](http://choosealicense.com/licenses/mit/)

## Author Information

 - [Tobias Schifftner](https://twitter.com/tschifftner), [ambimax® GmbH](https://www.ambimax.de)
