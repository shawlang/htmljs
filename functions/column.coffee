Column = __M 'columns'
User = __M "users"
Card = __M 'cards'
Article = __M 'articles'
User.hasOne Column,{foreignKey:"user_id"}
Column.belongsTo User,{foreignKey:"user_id"}
Column.hasMany Article,{foreignKey:"column_id",as:"articles"}
Column.sync()
ColumnRss = __M 'column_rsses'
ColumnRss.belongsTo Card,{foreignKey:"user_id"}
ColumnRss.sync()
func_email = __F 'email'

func_column = 
  getAll:(page,count,condition,order,include,callback)->
    if arguments.length == 4
      callback = order
      order = null
      include = null
    else if arguments.length == 5
      callback = include
      include = null
    query = 
      offset: (page - 1) * count
      limit: count
      order: order
      include:[User]
      raw:true
    if condition then query.where = condition
    Column.findAll(query)
    .success (result_columns)->
      callback null,result_columns
    .error (e)->
      callback e
  
  getAllWithArticle:(page,count,condition,desc,user_id,callback)->
    query = 
      offset: (page - 1) * count
      limit: count
      order: if desc then desc else "article_count desc"
    if condition then query.where = condition
    Column.findAll(query)
    .success (result_columns)->
      ids = []
      result_columns.forEach (column)->
        ids.push column.id
      Article.findAll 
        where:
          column_id:ids
        order:"id desc"
        raw:true
      .success (articles)->
        columns = []
        result_columns.forEach (col)->
          columns.push col.selectedValues
        columns.forEach (column)->
          column.articles = []
          articles.forEach (article)->
            if column.id == article.column_id
              column.articles.push article

        if user_id
          ColumnRss.findAll
            where:
              column_id:ids
              user_id:user_id
            raw:true
          .success (rss_logs)->
            rss_logs.forEach (log)->
              columns.forEach (col)->
                if col.id == log.column_id
                  col.is_rssed = true
            callback null,columns
          .error (e)->
            callback e
        else
          callback null,columns
      .error (e)->
        callback e
    .error (error)->
      callback error
  getById:(id,callback)->
    Column.find
      where:
        id:id
      include:[User]
      raw:true
    .success (column)->
      callback null,column
    .error (e)->
      callback e
  addRss:(column_id,user_id,callback)->
    ColumnRss.find
      where:
        column_id:column_id
        user_id:user_id
      raw:true
    .success (rss)->
      if rss
        callback new Error '已经订阅过此专栏'
      else
        func_column.addCount column_id,"rss_count",()->

        ColumnRss.create({user_id:user_id,column_id:column_id,uuid:uuid.v4()})
        .success (rss)->
          callback null,rss
        .error (e)->
          callback e
    .error (e)->
      callback e
  getRsses:(column_id,callback)->
    sequelize.query("SELECT `column_rsses`.*, `cards`.`email` AS `cards.email`,`cards`.`nick` AS `cards.nick` FROM `column_rsses` LEFT OUTER JOIN `cards` AS `cards` ON `cards`.`user_id` = `column_rsses`.`user_id` WHERE `column_rsses`.`column_id`='"+column_id+"';",null, {raw: true,redis:10000})
    .success (data)->
      callback null,data
    .error (e)->
      callback e
  getRssesByUserId:(user_id,callback)->
    ColumnRss.findAll
      where:
        user_id:user_id
      raw:true
    .success (rsses)->
      callback null,rsses
    .error (e)->
      callback e
  getUsersRss:(column_id,user_id,callback)->
    ColumnRss.find
      where:
        column_id:column_id
        user_id:user_id
      raw:true
    .success (rss)->
      if rss
        callback null,rss
      else
        callback new Error '没有订阅过此专栏'
    .error (e)->
      callback e
  checkNotify:(column_id)->
    Column.find
      where:
        id:column_id
    .success (column)->
      if column
        nowtime = new Date().getTime()
        if (nowtime - column.last_notify_time) >1000*60*60*24 #&& (nowtime - column.last_article_time) >1000*60*60*24*5
          Card.find
            where:
              user_id:column.user_id
          .success (card)->
            if card && card.email
              func_email.sendColumnNotify column,card
              column.updateAttributes({last_notify_time:nowtime})
__FC func_column,Column,['delete','add','addCount','count','update']
module.exports = func_column