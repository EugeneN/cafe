Cafe is a build tool for client-side applications aiming to be language/module system/architecture agnostic and flexible. Tries hard to be modular and extensible by itself too.

Among other things it features a zero-maintenance lifecycle management (keeps itself up to date automatically) and a network interface (can work as a server process accepting commands via remote network connections; useful for organizing build farms).

Current version (cafe4) is a prototype and is written in Coffeescript in functional and asynchronous way (mostly functional and mostly asynchronous :-).

#Installation

    npm install -g cafe4

#Usage

First init a cafe project with

    cafe init

This would create you template recipe file, where you can describe packages your app is using. Working recipe looks something like this:

```yaml
abstract: {api_version: 5}

modules:
    - module1: modules/module1
    - jquery: [jquery.1.8.js, plainjs]
    - module2: [modules/module2, [jquery]]
    - my_coffee_module: [my_coffee_file.coffee]

bundles:
    bundle1:
        modules:
            - jquery
            - module1
            - module2
            - my_coffee_module

    bundle2:
        modules:
            - jquery
            - module1
            - my_coffee_module
```

To compile your app run

    cafe menu build

For more details look at [getting started page](https://github.com/EugeneN/cafe/wiki/Cafe-get-started).

#Contributing
Don't forget to check that all tests are passing before commit (grunt nodeunit)
* clone this repo git clone https://github.com/EugeneN/cafe.git
* cd cafe
* grunt install | grunt coffee
* grunt build

#Changelog

0.0.90
* yaml recipe reader
* advanced recipe parsing logic
** aliases
** different formats for modules
* caching logic optimization. (2 times faster build process then in previous versions)

* Added growl notifications. (can be disabled by option --nogrowl).
