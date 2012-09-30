###
 This module is a fixture for Cafe 'bundle' target

 There's a bunch of objects, that have some dependencies between them.
 They are exported in alphabetical order.

 Topological sorting must put objects in a way,
 when including objects in the output order will successfully solves all deps


Scheme of objects dependencies:

                 grandpa    grandma
                     \        /
                      \      /
                       *    *
                       mother    father
                          |\      /|
                          | \    / |
                          |  \  /  |
                          |   \/   |
                          |   /\   |
                          |  /  \  |
                          | /    \ |
                          **      **
             wife         me     sister
               \          /
                \        /
                 \      /
                  \    /
                   *  *
                  child

 So, the output must be: "wife,grandpa,grandma,mother,father,sister,me,child"
###


grandpa =
    name: 'grandpa'
    deps: []

grandma =
    name: 'grandma'
    deps: []

father =
    name: 'father'
    deps: []

mother =
    name: 'mother'
    deps: ['grandpa', 'grandma']

me =
    name: 'me'
    deps: ['mother', 'father']

sister =
    name: 'sister'
    deps: ['mother', 'father']

wife =
    name: 'wife'
    deps: []

child =
    name: 'child'
    deps: ['me', 'wife']

module.exports = {
    child,
    father,
    grandma,
    grandpa,
    me,
    mother,
    sister,
    wife,
}