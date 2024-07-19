# Mongodb 常用命令

## 进入命令行

```sh
mongosh
```

## 创建 database

```sh
use [database]
```

## 查看当前 database

```sh
db
```

## 创建 collection

```sh
db.createCollection("[collection]")
```

## 查看所有 collection

```sh
show collections
```

## 删除 collection 中的所有文档

```sh
db.[collection].deleteMany({})
```

## 查看 collection 中的文档数量

```sh
db.[collection].countDocuments()
```