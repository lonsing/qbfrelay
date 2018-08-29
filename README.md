# README #

August 2018

### OVERVIEW ###

This is version 1.0 of QBFRelay.

QBFRelay is a shell script used to coordinate several quantified
Boolean formula (QBF) preprocessors. Currently, the preprocessors
[QxBF](http://fmv.jku.at/qxbf/),
[Bloqqer](http://fmv.jku.at/bloqqer/),
[HQSpre](https://projects.informatik.uni-freiburg.de/projects/dqbf/files),
and [QRATPre+](https://lonsing.github.io/qratpreplus/) are
supported. Other tools can easily be integrated.

QBFRelay runs the integrated preprocessors with a time limit in
multiple rounds on a given QBF in prenex CNF. Thereby, the formula
resulting from the application of one preprocessor is used as input of
the next preprocessor in an execution sequence. Preprocessing stops as
soon as the formula is solved or does not change anymore, or if the
time limit is exceeding.

QBFRelay is inspired by promising experimental results related to
incremental preprocessing ([Lonsing, Seidl, Van Gelder. The QBF
Gallery: Behind the Scenes. Artif. Intell., vol. 237,
2016](https://doi.org/10.1016/j.artint.2016.04.002)).

### USAGE INFORMATION ###

Run `qbfrelay.sh <options> <file.qdimacs>`

where `<options>` is a combination of the following:

* `-t <num>` : CPU time limit for each preprocessor call.

* `-s <num>` : space limit (MB) for each preprocessor call.

* `-r <num>` : max. number of rounds to be run.

* `-o <str>` : ordering of preprocessor calls specified as a string
  consisting of the letters *A* (QxBF), *Q* (QRATPre+), *B* (Bloqqer),
  and *D* (HQSpre) in any combination. Multiple occurrences are
  possible.

* `-p <file>` : print preprocessed formula to `file`.

* `-c` : completion mode; stop if instance does not change any more.

### INSTALLATION ###

The latest release is available from
[GitHub](https://github.com/lonsing/qbfrelay).

In the file *qbfrelay.sh*, adapt the paths to the directory
containing binaries (variable *BINDIR*, default `./`) and temporary
files (variable *TMPBASEDIR*, default `/tmp/`), if necessary.

QBFRelay uses the
[runsolver](http://www.cril.univ-artois.fr/~roussel/runsolver/) tool
to control the run time and [DepQBF](http://lonsing.github.io/depqbf/)
for pretty-printing of formulas.

* Download *runsolver* 3.3.5 from
  [http://www.cril.univ-artois.fr/~roussel/runsolver/runsolver-3.3.5.tar.bz2](http://www.cril.univ-artois.fr/~roussel/runsolver/runsolver-3.3.5.tar.bz2)
  and compile it.

* Download *DepQBF* from
  [https://github.com/lonsing/depqbf/archive/version-6.03.tar.gz](https://github.com/lonsing/depqbf/archive/version-6.03.tar.gz)
  and compile it.

Download and compile the following preprocessors:

* QxBF: [http://fmv.jku.at/qxbf/](http://fmv.jku.at/qxbf/)

* Bloqqer: [http://fmv.jku.at/bloqqer/](http://fmv.jku.at/bloqqer/)

* HQSpre:
  [https://projects.informatik.uni-freiburg.de/projects/dqbf/files](https://projects.informatik.uni-freiburg.de/projects/dqbf/files)

* QRATPre+:
  [https://lonsing.github.io/qratpreplus/](https://lonsing.github.io/qratpreplus/)

Put all binaries of tools into the *BINDIR* directory set above.

In the file *qbfrelay.sh*, adapt the paths to the binaries of the
preprocessors (variables *BLOQQER*, *HQSPRE*, *QXBF*, *RUNSOLVER*,
*DEPQBF*, and *QRATPREPLUS*).

### LICENSE ###

QBFRelay is free software released under GPLv3:

[https://www.gnu.org/copyleft/gpl.html](https://www.gnu.org/copyleft/gpl.html)

See also file LICENSE.

### CONTACT INFORMATION ###

For comments, questions, bug reports etc. related to QBFRelay, please
contact:

Florian Lonsing

[http://www.florianlonsing.com](http://www.florianlonsing.com)
