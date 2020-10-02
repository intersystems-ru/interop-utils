## interop-utils
This is a set of utility classes that might be of help when building interoperability productions on top of InterSystems IRIS or Ensemble.

## Installation 

Clone/git pull the repo into any local directory.

```
$ git clone https://github.com/intersystems-ru/interop-utils.git
```

Open InterSystems IRIS terminal, switch to the target namespace and import the classes from /src folder.

```
> do $System.OBJ.ImportDir("/tmp/interop-utils/src/", "*.cls", "ckbud", .err, 1)
```
