# .gdbinit file for debugging Mozilla
# trick to not load all the libraries.  saves tons of ram
set auto-solib-add 0

# run when using the auto-solib-add trick
def prun
        tbreak main
        run
        sha pthread
        cont
end

# run -mail, when using the auto-solib-add trick
def pmail
        tbreak main
        run -mail
        sha pthread
        cont
end

# you don't want these either
handle SIGPIPE nostop noprint
