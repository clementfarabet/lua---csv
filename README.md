# csv: a package to handle CSV files (read and write).

## Install:

First install Torch7 (www.torch.ch) then simply install this package
using torch-pkg:

```
torch-pkg install csv
```

or from the sources:

```
torch-pkg download csv
cd csv
torch-pkg deploy
```

## Use:

The library provides 2 high-level functions: csv.load and csv.save. To get help
on these functions, simply do:

```
> help(csv.save)
> help(csv.load)
```

Loading a CSV file in 'query' mode gives you a convenient query function that
you can use to query subsets of your original CSV file. To get help on this query
function, simply do:

```
> query = csv.load{path='somefile.csv', mode='query'}
> query('help')
-- print some help
> all = query('all')
> subset = query('union', {somevar=someval, someothervar={val1, val2}})
