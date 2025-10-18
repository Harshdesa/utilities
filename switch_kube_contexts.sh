kubectl config get-contexts -o name | fzf | xargs -I {} kubectl config use-context {}
