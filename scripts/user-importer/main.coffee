
createUsers = (users)->

  Bongo     = require 'bongo'

  { join: joinPath } = require 'path'
  { v4: createId }   = require 'node-uuid'

  argv      = require('minimist') process.argv
  KONFIG    = require('koding-config-manager').load("main.#{argv.c}")

  mongo     = "mongodb://#{ KONFIG.mongo }"
  modelPath = '../../workers/social/lib/social/models'
  rekuire   = (p)-> require joinPath modelPath, p

  koding = new Bongo
    root   : __dirname
    mongo  : mongo
    models : modelPath

  console.log "Trying to connect #{mongo} ..."

  koding.once 'dbClientReady', ->

    ComputeProvider      = rekuire 'computeproviders/computeprovider.coffee'
    JUser                = rekuire 'user/index.coffee'
    JPaymentSubscription = rekuire 'payment/subscription'

    createUser = (u, next)->

      console.log "\nCreating #{u.username} ... "

      JUser.count username: u.username, (err, count)->

        if err then return console.error "Failed to query count:", err

        if count > 0
          console.log "  User #{u.username} already exists, passing."
          return next()

        JUser.createUser u, (err, user, account)->

          if err

            console.log "Failed to create #{u.username}: ", err
            if err.errors?
              console.log "VALIDATION ERRORS: ", err.errors

            return next()

          account.update $set: type: 'registered', (err)->

            if err?
              console.log "  Failed to activate #{u.username}:", err
              return next()

            console.log "  User #{user.username} created."
            console.log "\n   - Verifying email ..."

            user.confirmEmail (err)->

              if err then console.log "     Failed to verify: ", err
              else        console.log "     Email verified."

              JUser.configureNewAcccount account, user, createId(), (err)->

                console.log "\n   - Adding to group #{u.group} ..."

                JUser.addToGroup account, u.group, u.email, null, (err)->

                  if err then console.log "     Failed to add: ", err
                  else        console.log "     Joined to group #{u.group}."

                  next()


    # An array like this

    # users = [{
    #   username       : "gokmen"
    #   email          : "gokmen@koding.com"
    #   password       : "gokmen"
    #   passwordStatus : "valid"
    #   firstName      : "Gokmen"
    #   lastName       : "Goksel"
    #   group          : "koding"
    #   foreignAuth    : null
    #   silence        : no
    # }]

    createUser users.shift(), createHelper = ->
      if   nextUser = users.shift()
      then createUser nextUser, createHelper
      else

        setTimeout ->
          console.log "\nALL DONE."
          process.exit 0
        , 10000


csv = require 'csv'

try

  console.log "Reading ./scripts/user-importer/team.csv ..."
  csv()

    .from.options trim: yes
    .from './scripts/user-importer/team.csv'
    .to.array (team)->

      header = team.shift()
      users  = []

      team.forEach (member)->

        item = {
          passwordStatus : "valid"
          foreignAuth    : null
          silence        : no
        }

        for column, i in header
          item[column] = member[i]

        users.push item

      console.log "Read completed, #{users.length} item found."
      createUsers users

catch e

  console.log "Failed to parse team.csv", e
  process.exit 0
