This is Learning project nothing more. Tokens are for local gitlab.
Steps to make this work
Start docker gitlab
Register 
Create project
Create repo
Create runner in gitlab depends on job switch with/without tags jobs you can create him for group of projects.
Run runner
You need to create branches that are needed in flow
Create Acess api token Mainainer api scope add it variable RELEASE_TOKEN
In Merge requests section check pipelines must succeed 
Protect main and develop branches
Because it's community version I created unnecessary stage that's checking approval count. It's only because I can't create approval rule in gitlab.
Adding ollama review I needed to add this rulesudo ufw allow from 172.18.0.0/16 to any port 11434 proto tcp
I think you should add another account and generate token for review. 
In project gitlab-ci parameters are needed for deploy on k3

