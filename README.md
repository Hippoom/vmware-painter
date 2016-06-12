# vmware-painter

Painter for VMware

## How to run it

    docker run --rm -it -v <your config file>:/etc/scaleworks/graph/vmware.yml scaleworks/vmware-painter:<version>

The configuration items are listed here:


    vcenter:
      host: https://192.168.11.105
      user: administrator@thoughtworks.cn
      password: 1qaz@WSX

    neo4j:
      host: 192.168.99.100
      port: 7474
    
    logging:
      level: INFO  
      
## How to contribute

Please use `vmware.dev.yml` for your local profile because `vmware.yml` is a shared file.

You can config your rbenv by entering `rbenv local $(cat .ruby-version)`.  

You can run the painter with 

    ruby lib/painter -c ./vmware.dev.yml


