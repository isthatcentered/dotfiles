X icon in the gutter for failing tests
diagnostics should only be updated when a test run is done otherwise it flickers. They should be cleared on thest run stoped
Have per runner test output to manually check the details view
prevent memory leaks/overload
run when ui is free. group events
make event bus generic
extract nopemessage
make fakes for nope event
refactor the tests to use those fakes



what is your process for implementing a feature, refactoring a feature, this is how the llm should work

not satisfied with the code an llm gave you, ask him to define the underlying rules of the code that was 
written and to ask you questions about every rule. This will allow you to diagnose the underlying issue.
then ralph loop it



always be ready to record

explain the concepts/best practices and rules that guide this refactor (ex: having independent module focused on a single responsability (one source of change))
add it to claude.md

time travel debugging


Nex:t 
- don't assert on private state to observe if a window is still opened or not, just observe the word before and after
- leverage fake for tests
- when closing neovim, the window consumer must be closed

- delegate filtering to the component instead of the service ? Or have a dedicated service per component? 
    the header knows about filter but only displays the path, the panel filters the list based on the given filters
- filters should be an array of name, state key,  shortcut, fn passed to the window consumer
- take a look at the tree view thingy

- prop testing lib
- review command
- spin up agents to analyze patterns for fake lib an then trnslate them to these tests
- run tests agent that runs the test for a specific file/... and only reports the failure/all passing

tutor spec redis and buildme a tutorial with key stuff to learn and resources to learn it
should generate the test cases too

- ultra opinionated code agent with brainstorm/plan/tdd mode/learn mode



when implementing a new feature, what is the state of the art, what are the known libraries,
how can you efficiently validate your changes/establish a good feedback loop?
