---
  - name: Init Swarm Master
    hosts: masters
    become: true
    gather_facts: False
    remote_user: ubuntu
    tasks:
      - name: Swarm Init
        command: sudo usermod -aG docker {{remote_user}}
        command: docker swarm init --advertise-addr {{ inventory_hostname }}

      - name: Get Worker Token
        command: docker swarm join-token worker -q
        register: worker_token

      - name: Show Worker Token
        debug: var=worker_token.stdout

      - name: Master Token
        command: docker swarm join-token manager -q
        register: master_token

      - name: Show Master Token
        debug: var=master_token.stdout


  - name: Join Swarm Cluster
    hosts: workers
    become: true
    remote_user: ubuntu
    gather_facts: False
    vars:
      token: "{{ hostvars[groups['masters'][0]]['worker_token']['stdout'] }}"
      master: "{{ hostvars[groups['masters'][0]]['inventory_hostname'] }}"
    tasks:
      - name: Join Swarm Cluster as a Worker
        command: sudo usermod -aG docker {{remote_user}}
        command: sudo docker swarm join --token {{ token }} {{ master }}:2377
        register: worker

      - name: Show Results
        debug: var=worker.stdout

      - name: Show Errors
        debug: var=worker.stderr
