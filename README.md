# csvigo: a package to handle CSV files (read and write).

## Install:

First install Torch7 (www.torch.ch) then simply install this package
using torch-rocks:

```
luarocks install csvigo
```

## Use:

The library provides 2 high-level functions: csvigo.load and csvigo.save. To get help
on these functions, simply do:

```
> help(csvigo.save)
> help(csvigo.load)
```

Loading a CSV file in 'query' mode gives you a convenient query function that
you can use to query subsets of your original CSV file. To get help on this query
function, simply do:

```
> query = csvigo.load{path='somefile.csv', mode='query'}
> query('help')
-- print some help
> all = query('all')
> subset = query('union', {somevar=someval, someothervar={val1, val2}})
