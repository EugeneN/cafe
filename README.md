#Introduction

cafe is a project for compiling CommonJS modules when building JavaScript web 
applications. You can think of cafe as [Bundler](http://gembundler.com/) for Node, 
or [Stitch](https://github.com/sstephenson/stitch) on steroids. 

This is rather awesome, as it means you don't need to faff around with coping 
around JavaScript files. jQuery can be a npm dependency, so can jQueryUI and 
all your custom components. cafe will resolve dependencies dynamically, bundling 
them together into one file to be served up. Upon deployment, you can serialize 
your application to disk and serve it statically. 

#Installation

    npm install -g cafe

#Usage

Please see the [cafe guide](http://kyle/confluence/cafe) for usage instructions.
