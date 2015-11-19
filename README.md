# csvigo: a package to handle CSV files (read and write).

## Install:

First install Torch7 (www.torch.ch) then simply install this package
using luarocks:

```
luarocks install csvigo
```

## Use:

The library provides 2 high-level functions: csvigo.load and csvigo.save. To get help
on these functions, simply do:

```
> csvigo.save()
> csvigo.load()
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
```

## Large CSV mode

CSVigo supports efficient loading of very large CSV files into memory.
The loaded data structure is a read-only table with efficiency hidden under the hood.

Loading:

```lua
m = csvigo.load({path = "my_large.csv", mode = "large"})
```

Printing by default only prints first 10 and last 10 rows
```lua
print(m)
```

Individual element access
```lua
print(m[32])
```

Size of table:
```lua
print(#m)
```

For loop over entries:

Type 1:
```lua
for i=1, #m do
    print(m[i]) -- get element
end
```

Type 2:
```lua
for k,v in ipairs(m) do
    print(k)
    print(v)
end
```

Type 3:
```lua
for k,v in pairs(m) do
    print(k)
    print(v)
end
```

Read-only table
```lua
-- read only table, will error here:
m[13] = 'a'
```
