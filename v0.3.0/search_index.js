var documenterSearchIndex = {"docs":
[{"location":"api/#API","page":"API Documentation","title":"API","text":"","category":"section"},{"location":"api/","page":"API Documentation","title":"API Documentation","text":"TransformSpecifications.TransformSpecifications","category":"page"},{"location":"api/#TransformSpecifications.TransformSpecifications","page":"API Documentation","title":"TransformSpecifications.TransformSpecifications","text":"TransformSpecifications\n\nThis package enables structured transform elements via defined I/O specifications.\n\n\n\n\n\n","category":"module"},{"location":"api/#Exported-functions-and-types","page":"API Documentation","title":"Exported functions and types","text":"","category":"section"},{"location":"api/","page":"API Documentation","title":"API Documentation","text":"","category":"page"},{"location":"api/#Non-exported-functions-and-types","page":"API Documentation","title":"Non-exported functions and types","text":"","category":"section"},{"location":"api/","page":"API Documentation","title":"API Documentation","text":"Modules = [TransformSpecifications]\nPublic = false","category":"page"},{"location":"api/#TransformSpecifications._validate_input_assembler-Tuple{NoThrowDAG, Nothing}","page":"API Documentation","title":"TransformSpecifications._validate_input_assembler","text":"_validate_input_assembler(dag::NoThrowDAG, input_assembler::TransformSpecification)\n_validate_input_assembler(dag::NoThrowDAG, ::Nothing)\n\nConfirm that an input_assembler, when called on all upstream outputs generated by dag, has access to all fields it needs to construct its input.\n\nThis validation assumes that the dag being validated against contains only outputs from upstream steps, an assumption that will be true on DAG construction (where this validation is called from). If called at other times, validation may succeed even though the input_assembler will fail when called in situ.\n\n\n\n\n\n","category":"method"},{"location":"api/#TransformSpecifications.convert_spec-Union{Tuple{T}, Tuple{Type{T}, T}} where T","page":"API Documentation","title":"TransformSpecifications.convert_spec","text":"convert_spec(::Type{T}, input::T) where {T}\nconvert_spec(::Type{T}, input::T) where {T<:Legolas.AbstractRecord}\nconvert_spec(spec::Type{<:Legolas.AbstractRecord}, input)\nconvert_spec(spec, input)\n\nReturn input interpreted as type T: is same as identity function if input is already of type T; otherwise, attempts to construct or Base.converts the the output type from the input. Will throw if conversion fails or is otherwise undefined.\n\nSee also: transform!\n\n\n\n\n\n","category":"method"},{"location":"api/#TransformSpecifications.field_dict-Tuple{Type{<:NoThrowResult}}","page":"API Documentation","title":"TransformSpecifications.field_dict","text":"field_dict(type::Type{<:NoThrowResult})\nfield_dict(type)\n\nReturn a Dict where keys are fieldnames(type) and the value of each key is that field's own type. Constructed by calling field_dict_value on each input field's type.\n\nWhen type is a NoThrowResult{T}, generate mapping based on unwrapped type T.\n\nTo recurse into a specific type MyType, implement\n\nTransformSpecification.field_dict_value(t::Type{MyType}) = field_dict(t)\n\nwarning: Warning\nUse caution when implementing a field_dict_value for any type that isn't explicitly impossible to lead to recursion, as otherwise a stack overflow may occur.\n\n\n\n\n\n","category":"method"},{"location":"api/#TransformSpecifications.identity_no_throw_result-Tuple{Any}","page":"API Documentation","title":"TransformSpecifications.identity_no_throw_result","text":"identity_no_throw_result(result) -> NoThrowResult\n\nReturn NoThrowResult{T} where T=typeof(result)\n\n\n\n\n\n","category":"method"},{"location":"api/#TransformSpecifications.is_input_assembler-Tuple{AbstractTransformSpecification}","page":"API Documentation","title":"TransformSpecifications.is_input_assembler","text":"is_input_assembler(ts::AbstractTransformSpecification) -> Bool\n\nConfirm that ts is an input_assembler.\n\n\n\n\n\n","category":"method"},{"location":"","page":"Home","title":"Home","text":"<script type=\"module\">\nimport mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.esm.min.mjs';\nmermaid.initialize({ startOnLoad: true });\n</script>","category":"page"},{"location":"#TransformSpecifications.jl","page":"Home","title":"TransformSpecifications.jl","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Enabling structured transformations via defined I/O specifications.","category":"page"},{"location":"#Introduction-and-Overview","page":"Home","title":"Introduction & Overview","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"This package provides tools to define explicitly-specified transformation components. Such components can then be used to define pipelines that are themselves composed of individual explicitly-specified components, or facilitate distributed computation. One primary use-case is in creating explicitly defined pipelines that chain components together. These pipelines are in the form of directed acyclic graphs (DAGs), where each node of the graph is a component, and the edges correspond to data transfers between the components. The graph is \"directed\" since data flows in one direction (from the outputs of a component to the inputs of another), and \"acyclic\" since cycles are not allowed; one component cannot supply data to another which then supplies data back to the original component.","category":"page"},{"location":"","page":"Home","title":"Home","text":"Later in the documentation, we will get into a lot more details about the tools that this package provides. But first, let us look at the high-level steps one follows to define such a pipeline using this package.","category":"page"},{"location":"","page":"Home","title":"Home","text":"Define the inputs and outputs of each step. TransformSpecifications itself does not provide (nor require) specific types for defining inputs and outputs, but this is commonly implemented via Legolas.jl schemas.\nDefine functions that takes each set inputs to the corresponding outputs. For the purposes of setting up the pipeline, these can be placeholder functions that don't actually do anything, but once you want to run the pipeline, these will need to do whatever work is required in order to generate the outputs from the inputs. Again, this step is independent of any code in TransformSpecifications.jl itself.\nPackage up steps (1) and (2) into AbstractTransformSpecifications, like TransformSpecification and NoThrowTransform. These are the \"components\", the nodes of the graph.\nCreate input_assemblers for each component to route necessary outputs of previous components into the inputs of the component. This creates the edges of the graph.\nCreate a DAG using DAGStep or NoThrowDAG to assemble all of the components and assemblers into a DAG.\nUse it! Apply the DAG to inputs using transform! or transform, and create a mermaid diagram using mermaidify.","category":"page"},{"location":"","page":"Home","title":"Home","text":"With these general steps in mind, it can help to see some examples.","category":"page"},{"location":"","page":"Home","title":"Home","text":"For example of all of these steps together, see NoThrowDAG.\nFor a basic concrete transform, see TransformSpecification\nFor transforms that catch exceptions and return them as formatted violations, see NoThrowTransform (and NoThrowResult).\nFor the abstract interface, see TransformSpecifications interface\nFor a compound transform that is itself a concrete AbstractTransformSpecification and is constructed from a DAG of AbstractTransformSpecifications, see NoThrowDAG\nFor a plotted graph visualization of such a DAG, see Plotting NoThrowDAGs.","category":"page"},{"location":"#Table-of-contents","page":"Home","title":"Table of contents","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Pages = [\"index.md\", \"api.md\"]\nDepth = 3","category":"page"},{"location":"#TransformSpecification","page":"Home","title":"TransformSpecification","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Modules = [TransformSpecifications]\nPages = [\"transform.jl\"]\nPrivate = false","category":"page"},{"location":"#TransformSpecifications.TransformSpecification","page":"Home","title":"TransformSpecifications.TransformSpecification","text":"TransformSpecification{T<:Type,U<:Type} <: AbstractTransformSpecification\n\nBasic component that specifies a transform that, when applied to input of type T, will return output of type U.\n\nSee also: TransformSpecification\n\nFields\n\ninput_specification::T\noutput_specification::U\ntransform_fn::Function Function with signature transform_fn(::input_specification) -> output_specification\n\nExample\n\nusing Legolas: @schema, @version\n\n@schema \"example-in\" ExampleInSchema\n@version ExampleInSchemaV1 begin\n    in_name::String\nend\n\n@schema \"example-out\" ExampleOutSchema\n@version ExampleOutSchemaV1 begin\n    out_name::String\nend\n\nfunction apply_example(in_record)\n    out_name = in_record.in_name * \" earthling\"\n    return ExampleOutSchemaV1(; out_name)\nend\nts = TransformSpecification(ExampleInSchemaV1, ExampleOutSchemaV1, apply_example)\n\n# output\nTransformSpecification{ExampleInSchemaV1,ExampleOutSchemaV1}: `apply_example`\n\ntransform!(ts, ExampleInSchemaV1(; in_name=\"greetings\"))\n\n# output\nExampleOutSchemaV1: (out_name = \"greetings earthling\",)\n\n\n\n\n\n","category":"type"},{"location":"#TransformSpecifications.transform!-Tuple{TransformSpecification, Any}","page":"Home","title":"TransformSpecifications.transform!","text":"transform!(ts::TransformSpecification, input)\n\nReturn output_specification(ts) by applying ts.transform_fn to input. May error if:\n\ninput does not conform to input_specification(ts), i.e.,   convert_spec(input_specification(ts), input) errors\nts.transform_fn errors when applied to the interpreted input, or\nthe output generated by ts.transform_fn is not a output_specification(ts)\n\nFor a non-erroring alternative, see NoThrowTransform.\n\nSee also: convert_spec\n\n\n\n\n\n","category":"method"},{"location":"#NoThrowTransform","page":"Home","title":"NoThrowTransform","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"NoThrowTransforms are a way to wrap a transform such that any errors encountered during the application of the transform will be returned as a NoThrowResult rather than thrown as an exception.","category":"page"},{"location":"","page":"Home","title":"Home","text":"tip: Debugging tip\nTo get the stack trace for a violation generated by a NoThrowTransform, call transform_force_throw! on it instead of transform!.","category":"page"},{"location":"","page":"Home","title":"Home","text":"Modules = [TransformSpecifications]\nPages = [\"nothrow.jl\"]\nPrivate = false","category":"page"},{"location":"#TransformSpecifications.NoThrowResult","page":"Home","title":"TransformSpecifications.NoThrowResult","text":"NoThrowResult(result::T, violations, warnings) where {T}\nNoThrowResult(result; violations=String[], warnings=String[])\nNoThrowResult(; result=missing, violations=String[], warnings=String[])\n\nType that specifies the result of a transformation, indicating successful application of a transform through presence (or lack thereof) of violations. Consists of either a non-missing result (success state) or non-empty violations and type Missing (failure state).\n\nNote that constructing a NoThrowTransform from an input result of type NoThrowTransform, e.g., NoThrowTransform(::NoThrowTransform{T}, ...), collapses down to a singleNoThrowResult{T}; any inner and outer warnings and violations fields are concatenated and returned in the resultantNoThrowResult{T}`.\n\nSee also: nothrow_succeeded\n\nFields\n\nwarnings::AbstractVector{<:AbstractString}: List of generated warnings that are not critical   enough to be violations.\nviolations::AbstractVector{<:AbstractString} List of reason(s) result was not able to be generated.\nresult::: Generated result; missing if any violations encountered.\n\nExample\n\nusing Legolas: @schema, @version\n@schema \"example\" ExampleSchemaA\n@version ExampleSchemaAV1 begin\n    name::String\nend\n\nNoThrowResult(ExampleSchemaAV1(; name=\"yeehaw\"))\n\n# output\nNoThrowResult{ExampleSchemaAV1}: Transform succeeded\n  ✅ result:\nExampleSchemaAV1: (name = \"yeehaw\",)\n\nNoThrowResult(ExampleSchemaAV1(; name=\"huzzah\"); warnings=\"Hark, watch your step...\")\n\n# output\nNoThrowResult{ExampleSchemaAV1}: Transform succeeded\n  ⚠️  Hark, watch your step...\n  ✅ result:\nExampleSchemaAV1: (name = \"huzzah\",)\n\nNoThrowResult(; violations=[\"Epic fail!\", \"Slightly less epic fail!\"],\n                warnings=[\"Uh oh...\"])\n\n# output\nNoThrowResult{Missing}: Transform failed\n  ❌ Epic fail!\n  ❌ Slightly less epic fail!\n  ⚠️  Uh oh...\n\n\n\n\n\n","category":"type"},{"location":"#TransformSpecifications.NoThrowTransform","page":"Home","title":"TransformSpecifications.NoThrowTransform","text":"NoThrowTransform{TransformSpecification{T<:Type,U<:Type}} <: AbstractTransformSpecification\n\nWrapper around a basic TransformSpecification that returns a NoThrowResult of type NoThrowResult{T}, where T is the output specification of the inner transform. If calling transform! on a NoThrowTransform errors, due to either incorrect input/output types or an exception during the transform itself, the exception will be caught and returned as a NoThrowResult{Missing}, with the error(s) in the result's violations field. See NoThrowResult for details.\n\nNote that results of a NoThrowTransform collapse down to a single NoThrowResult when nested, such that if the outputspecification of the inner TransformSpecification is itself a NoThrowResult{T}, the outputspecification of the NoThrowTransform will have that same output specification NoThrowResult{T}, and not NoThrowResult{NoThrowResult{T}}.\n\nFields\n\ntransform_spec::TransformSpecification{T,U}\n\nExample 1: Successful transformation\n\nSet-up:\n\nusing Legolas: @schema, @version\n\n@schema \"example-a\" ExampleSchemaA\n@version ExampleSchemaAV1 begin\n    in_name::String\nend\n\n@schema \"example-b\" ExampleSchemaB\n@version ExampleSchemaBV1 begin\n    out_name::String\nend\n\nfunction apply_example(in_record)\n    out_name = in_record.in_name * \" earthling\"\n    return ExampleSchemaBV1(; out_name)\nend\nntt = NoThrowTransform(ExampleSchemaAV1, ExampleSchemaBV1, apply_example)\n\n# output\nNoThrowTransform{ExampleSchemaAV1,ExampleSchemaBV1}: `apply_example`\n\nApplication of transform:\n\ntransform!(ntt, ExampleSchemaAV1(; in_name=\"greetings\"))\n\n# output\nNoThrowResult{ExampleSchemaBV1}: Transform succeeded\n  ✅ result:\nExampleSchemaBV1: (out_name = \"greetings earthling\",)\n\nExample 2: Failing transformation\n\nSet-up:\n\nforce_failure_example(in_record) = NoThrowResult(; violations=[\"womp\", \"womp\"])\nntt = NoThrowTransform(ExampleSchemaAV1, ExampleSchemaBV1, force_failure_example)\n\n# output\nNoThrowTransform{ExampleSchemaAV1,ExampleSchemaBV1}: `force_failure_example`\n\nApplication of transform:\n\ntransform!(ntt, ExampleSchemaAV1(; in_name=\"greetings\"))\n\n# output\nNoThrowResult{Missing}: Transform failed\n  ❌ womp\n  ❌ womp\n\n\n\n\n\n","category":"type"},{"location":"#TransformSpecifications.NoThrowTransform-Tuple{Type}","page":"Home","title":"TransformSpecifications.NoThrowTransform","text":"NoThrowTransform(specification::Type)\n\nCreate NoThrowTransform that meets the criteria of an identity NoThrowTransform, i.e., is_identity_no_throw_transform.\n\nSee also: identity_no_throw_result\n\n\n\n\n\n","category":"method"},{"location":"#TransformSpecifications.is_identity_no_throw_transform-Tuple{NoThrowTransform}","page":"Home","title":"TransformSpecifications.is_identity_no_throw_transform","text":"is_identity_no_throw_transform(ntt::NoThrowTransform) -> Bool\n\nCheck if ntt meets the definition of an identity NoThrowTransform, namely, output_specification(ntt) == NoThrowTransform{input_specification(ntt)} and transform function is identity_no_throw_result.\n\n\n\n\n\n","category":"method"},{"location":"#TransformSpecifications.nothrow_succeeded-Tuple{NoThrowResult{Missing}}","page":"Home","title":"TransformSpecifications.nothrow_succeeded","text":"nothrow_succeeded(result::NoThrowResult) -> Bool\n\nReturn true if result indicates successful completion, i.e. if result.violations is empty.\n\nSee also: NoThrowResult\n\n\n\n\n\n","category":"method"},{"location":"#TransformSpecifications.transform!-Tuple{NoThrowTransform, Any}","page":"Home","title":"TransformSpecifications.transform!","text":"transform!(ntt::NoThrowTransform, input)\n\nReturn NoThrowResult of applying ntt.transform_spec.transform_fn to input. Transform will fail (i.e., return a NoThrowResult{Missing} if:\n\ninput does not conform to input_specification(ntt), i.e.,   convert_spec(input_specification(ntt), input) throws an error\nntt.transform_spec.transform_fn returns a NoThrowResult{Missing} when applied to the interpreted input,\nntt.transform_spec.transform_fn errors when applied to the interpreted input, or\nthe output generated by ntt.transform_spec.transform_fn is not a Union{NoThrowResult{Missing},output_specification(ntt)}\n\nIn any of these failure cases, this function will not throw, but instead will return the cause of failure in the output violations field.\n\nnote: Note\n\n\nFor debugging purposes, it may be helpful to bypass the \"no-throw\" feature and   so as to have access to a callstack. To do this, use transform_force_throw!   in place of transform!.\n\nSee also: convert_spec\n\n\n\n\n\n","category":"method"},{"location":"#TransformSpecifications.transform_force_throw!-Tuple{NoThrowTransform, Any}","page":"Home","title":"TransformSpecifications.transform_force_throw!","text":"transform_force_throw!(ntt::NoThrowTransform, input)\n\nApply transform! on inner ntt.transform_spec, such that the resultant output will be of type output_specification(ntt.transform_spec) rather than a NoThrowResult, any failure will result in throwing an error. Utility for debugging NoThrowTransforms.\n\nSee also: transform_force_throw\n\n\n\n\n\n","category":"method"},{"location":"#TransformSpecifications.transform_force_throw-Tuple{NoThrowTransform, Any}","page":"Home","title":"TransformSpecifications.transform_force_throw","text":"transform_force_throw(ntt::NoThrowTransform, input)\n\nNon-mutating implmementation of transform_force_throw!; applies transform(ntt.transform_spec, input).\n\n\n\n\n\n","category":"method"},{"location":"#NoThrowDAG","page":"Home","title":"NoThrowDAG","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"NoThrowDAGs are a way to compose multiple specified transforms (DAGStep) into a DAG, such that any errors errors encountered during the application of the DAG will be returned as a NoThrowResult rather than thrown as an exception.","category":"page"},{"location":"","page":"Home","title":"Home","text":"tip: Debugging tips\nTo debug the source of a returned violation from a NoThrowDAG, call transform_force_throw! on it instead of transform!. Errors (and their stack traces) will be thrown directly, rather than returned nicely as NoThrowResults. Alternatively/additionally, create your DAG from a subset of its constituent steps. Bisecting the full DAG chain can help zero in on errors in DAG construction: e.g.,  transform!(NoThrowDAG(steps[1:4]), input), etc.","category":"page"},{"location":"","page":"Home","title":"Home","text":"Modules = [TransformSpecifications]\nPages = [\"nothrow_dag.jl\"]\nPrivate = false","category":"page"},{"location":"#TransformSpecifications.DAGStep","page":"Home","title":"TransformSpecifications.DAGStep","text":"DAGStep\n\nHelper struct, used to construct NoThrowDAGs. Requires fields\n\nname::String: Name of step, must be unique across a constructed DAG\ninput_assembler::TransformSpecification: Transform used to construct step's input;   see input_assembler for details.\ntransform_spec::AbstractTransformSpecification: Transform applied by step\n\n\n\n\n\n","category":"type"},{"location":"#TransformSpecifications.NoThrowDAG","page":"Home","title":"TransformSpecifications.NoThrowDAG","text":"NoThrowDAG <: AbstractTransformSpecification\nNoThrowDAG(steps::AbstractVector{DAGStep})\n\nTransform specification constructed from a DAG of transform specification nodes (steps), such that calling transform! on the DAG iterates through the steps, first constructing that step's input from all preceding upstream step outputs and then appling that step's own transform to the constructed input.\n\nThe DAG's input_specification is that of the first step in the DAG; its output_specification is that of the last step. As the first step's input is by definition the same as the overall input to the DAG, its step.input_assembler must be nothing.\n\ntip: DAG construction tip\nAs the input to the DAG at is by definition the input to the first step in that DAG, only the first step will have access to the input directly passed in by the caller. To grant access to this top-level input to downstream tasks, construct the DAG with an initial step that is an identity transform, i.e., is_identity_no_throw_transform(first(steps)) returns true. Downstream steps can then depend on the output of specific fields from this initial step. The single argument TransformSpecification constructor creates such an identity transform.\n\nwarning: DAG construction warning\nIt is the caller's responsibility to implement a DAG, and to not introduce any recursion or cycles. What will happen if you do? To quote Tom Lehrer, \"well, you ask a silly question, you get a silly answer!\"\n\nwarning: Storage of intermediate values\nThe output of each step in the DAG is stored locally in memory for the entire lifetime of the transform operation, whether or not it is actually accessed by any later steps.  Large intermediate outputs may result in unexpected memory pressure relative to function composition or even local evaluation (since they are not visible to the garbage collector).\n\nFields\n\nThe following fields are constructed automatically when constructing a NoThrowDAG from a vector of DAGSteps:\n\nstep_transforms::OrderedDict{String,AbstractTransformSpecification}: Ordered dictionary of processing steps\nstep_input_assemblers::Dict{String,TransformSpecification}: Dictionary with functions for constructing the input   for each key in step_transforms as a function that takes in a Dict{String,NoThrowResult}   of all upstream step_transforms results.\n_step_output_fields::Dict{String,Dict{Symbol,Any}}: Internal mapping of upstream step   outputs to downstream inputs, used to e.g. valdiate that the input to each step   can be constructed from the outputs of the upstream steps.\n\nExample\n\nusing Legolas: @schema, @version\n\n@schema \"example-one-var\" ExampleOneVarSchema\n@version ExampleOneVarSchemaV1 begin\n    var::String\nend\n\n@schema \"example-two-var\" ExampleTwoVarSchema\n@version ExampleTwoVarSchemaV1 begin\n    var1::String\n    var2::String\nend\n\n# Say we have three functions we want to chain together:\nfn_a(x) = ExampleOneVarSchemaV1(; var=x.var * \"_a\")\nfn_b(x) = ExampleOneVarSchemaV1(; var=x.var * \"_b\")\nfn_c(x) = ExampleOneVarSchemaV1(; var=x.var1 * x.var2 * \"_c\")\n\n# First, specify these functions as transforms: what is the specification of the\n# function's input and output?\nstep_a_transform = NoThrowTransform(ExampleOneVarSchemaV1, ExampleOneVarSchemaV1, fn_a)\nstep_b_transform = NoThrowTransform(ExampleOneVarSchemaV1, ExampleOneVarSchemaV1, fn_b)\nstep_c_transform = NoThrowTransform(ExampleTwoVarSchemaV1, ExampleOneVarSchemaV1, fn_c)\n\n# Next, set up the DAG between the upstream outputs into each step's input:\nstep_b_assembler = input_assembler(upstream -> (; var=upstream[\"step_a\"][:var]))\nstep_c_assembler = input_assembler(upstream -> (; var1=upstream[\"step_a\"][:var],\n                                                var2=upstream[\"step_b\"][:var]))\n# ...note that step_a is skipped, as there are no steps upstream from it.\n\nsteps = [DAGStep(\"step_a\", nothing, step_a_transform),\n         DAGStep(\"step_b\", step_b_assembler, step_b_transform),\n         DAGStep(\"step_c\", step_c_assembler, step_c_transform)]\ndag = NoThrowDAG(steps)\n\n# output\nNoThrowDAG (ExampleOneVarSchemaV1 => ExampleOneVarSchemaV1):\n  🌱  step_a: ExampleOneVarSchemaV1 => ExampleOneVarSchemaV1: `fn_a`\n   ·  step_b: ExampleOneVarSchemaV1 => ExampleOneVarSchemaV1: `fn_b`\n  🌷  step_c: ExampleTwoVarSchemaV1 => ExampleOneVarSchemaV1: `fn_c`\n\nThis DAG can then be applied to an input, just like a regular TransformSpecification can:\n\ninput = ExampleOneVarSchemaV1(; var=\"initial_str\")\ntransform!(dag, input)\n\n# output\nNoThrowResult{ExampleOneVarSchemaV1}: Transform succeeded\n  ✅ result:\nExampleOneVarSchemaV1: (var = \"initial_str_ainitial_str_a_b_c\",)\n\nSimilarly, this transform will fail if the input specification is violated–-but because it returns a NoThrowResult, it will fail gracefully:\n\n# What is the input specification?\ninput_specification(dag)\n\n# output\nExampleOneVarSchemaV1\n\ntransform!(dag, ExampleTwoVarSchemaV1(; var1=\"wrong\", var2=\"input schema\"))\n\n# output\nNoThrowResult{Missing}: Transform failed\n  ❌ Input to step `step_a` doesn't conform to specification `ExampleOneVarSchemaV1`. Details: ArgumentError(\"Invalid value set for field `var`, expected String, got a value of type Missing (missing)\")\n\nTo visualize this DAG, you may want to generate a plot via mermaid, which is a markdown-like plotting language that is rendered automatically via GitHub and various other platforms. To create a mermaid plot of a DAG, use mermaidify:\n\nmermaid_str = mermaidify(dag)\n\n# No need to dump full output string here, but let's check that the results are\n# the same as in our generated ouptut test, so that we know that the rendered graph\n# in the documentation stays synced with the code.\nprint(mermaid_str)\n\n# output\nflowchart\n\n%% Define steps (nodes)\nsubgraph OUTERLEVEL[\"` `\"]\ndirection LR\nsubgraph STEP_A[Step a]\n  direction TB\n  subgraph STEP_A_InputSchema[Input: ExampleOneVarSchemaV1]\n    direction RL\n    STEP_A_InputSchemavar{{\"var::String\"}}\n    class STEP_A_InputSchemavar classSpecField\n  end\n  subgraph STEP_A_OutputSchema[Output: ExampleOneVarSchemaV1]\n    direction RL\n    STEP_A_OutputSchemavar{{\"var::String\"}}\n    class STEP_A_OutputSchemavar classSpecField\n  end\n  STEP_A_InputSchema:::classSpec -- fn_a --> STEP_A_OutputSchema:::classSpec\nend\nsubgraph STEP_B[Step b]\n  direction TB\n  subgraph STEP_B_InputSchema[Input: ExampleOneVarSchemaV1]\n    direction RL\n    STEP_B_InputSchemavar{{\"var::String\"}}\n    class STEP_B_InputSchemavar classSpecField\n  end\n  subgraph STEP_B_OutputSchema[Output: ExampleOneVarSchemaV1]\n    direction RL\n    STEP_B_OutputSchemavar{{\"var::String\"}}\n    class STEP_B_OutputSchemavar classSpecField\n  end\n  STEP_B_InputSchema:::classSpec -- fn_b --> STEP_B_OutputSchema:::classSpec\nend\nsubgraph STEP_C[Step c]\n  direction TB\n  subgraph STEP_C_InputSchema[Input: ExampleTwoVarSchemaV1]\n    direction RL\n    STEP_C_InputSchemavar1{{\"var1::String\"}}\n    class STEP_C_InputSchemavar1 classSpecField\n    STEP_C_InputSchemavar2{{\"var2::String\"}}\n    class STEP_C_InputSchemavar2 classSpecField\n  end\n  subgraph STEP_C_OutputSchema[Output: ExampleOneVarSchemaV1]\n    direction RL\n    STEP_C_OutputSchemavar{{\"var::String\"}}\n    class STEP_C_OutputSchemavar classSpecField\n  end\n  STEP_C_InputSchema:::classSpec -- fn_c --> STEP_C_OutputSchema:::classSpec\nend\n\n%% Link steps (edges)\nSTEP_A:::classStep -..-> STEP_B:::classStep\nSTEP_B:::classStep -..-> STEP_C:::classStep\n\nend\nOUTERLEVEL:::classOuter ~~~ OUTERLEVEL:::classOuter\n\n%% Styling definitions\nclassDef classOuter fill:#cbd7e2,stroke:#000,stroke-width:0px;\nclassDef classStep fill:#eeedff,stroke:#000,stroke-width:2px;\nclassDef classSpec fill:#f8f7ff,stroke:#000,stroke-width:1px;\nclassDef classSpecField fill:#fff,stroke:#000,stroke-width:1px;\n\nSee this rendered plot in the built documentation.\n\nTo display a mermaid plot via e.g. Documenter.jl, additional setup will be required.\n\n\n\n\n\n","category":"type"},{"location":"#TransformSpecifications.get_step-Tuple{NoThrowDAG, String}","page":"Home","title":"TransformSpecifications.get_step","text":"get_step(dag::NoThrowDAG, name::String) -> DAGStep\nget_step(dag::NoThrowDAG, step_index::Int) -> DAGStep\n\nReturn DAGStep with name or step_index.\n\n\n\n\n\n","category":"method"},{"location":"#TransformSpecifications.input_assembler-Tuple{Any}","page":"Home","title":"TransformSpecifications.input_assembler","text":"input_assembler(conversion_fn) -> TransformSpecification{Dict{String,Any}, NamedTuple}\n\nSpecial transform used to convert the outputs of upstream steps in a NoThrowDAG into a NamedTuple that can be converted into that type's input specification.\n\nconversion_fn must be a function that\n\ntakes as input a Dictionary with keys that are the names of upstream steps, where   the value of each of these keys is the output of that upstreamstep, as   specified by `outputspecification(upstream_step)`.\nreturns a NamedTuple that can be converted, via convert_spec, to the   specification of an AbstractTransformSpecification that it is paired with   in a DAGStep.\n\nNote that the current implementation is a stopgap for a better-defined implementation defined in https://github.com/beacon-biosignals/TransformSpecifications.jl/issues/8\n\n\n\n\n\n","category":"method"},{"location":"#TransformSpecifications.input_specification-Tuple{NoThrowDAG}","page":"Home","title":"TransformSpecifications.input_specification","text":"input_specification(dag::NoThrowDAG)\n\nReturn input_specification of first step in dag, which is the input specification of the entire DAG.\n\nSee also: output_specification, NoThrowDAG\n\n\n\n\n\n","category":"method"},{"location":"#TransformSpecifications.output_specification-Tuple{NoThrowDAG}","page":"Home","title":"TransformSpecifications.output_specification","text":"output_specification(dag::NoThrowDAG) -> Type{<:Legolas.AbstractRecord}\n\nReturn output_specification of last step in dag, which is the output specification of the entire DAG.\n\nSee also: input_specification, NoThrowDAG\n\n\n\n\n\n","category":"method"},{"location":"#TransformSpecifications.transform!-Tuple{NoThrowDAG, Any}","page":"Home","title":"TransformSpecifications.transform!","text":"transform!(dag::NoThrowDAG, input)\n\nReturn NoThrowResult of sequentially transform!ing all dag.step_transforms, after passing input to the first step.\n\nBefore each step, that step's input_assembler is called on the results of all previous processing steps; this constructor generates input that conforms to the step's input_specification.\n\nSee also: transform_force_throw!\n\n\n\n\n\n","category":"method"},{"location":"#TransformSpecifications.transform_force_throw!-Tuple{NoThrowDAG, Any}","page":"Home","title":"TransformSpecifications.transform_force_throw!","text":"transform_force_throw!(dag::NoThrowDAG, input)\n\nUtility for debugging NoThrowDAGs by consecutively applying transform!(step, input) on each step, such that the output of each step is of type output_specification(step.transform_spec) rather than a NoThrowResult, and any failure will result in throwing an error.\n\n\n\n\n\n","category":"method"},{"location":"#Plotting-NoThrowDAGs","page":"Home","title":"Plotting NoThrowDAGs","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Here is the mermaid plot generated for the example DAG in NoThrowDAG:","category":"page"},{"location":"","page":"Home","title":"Home","text":"<div class=\"mermaid\">\nflowchart\n\n%% Define steps (nodes)\nsubgraph OUTERLEVEL[\"` `\"]\ndirection LR\nsubgraph STEP_A[Step a]\n  direction TB\n  subgraph STEP_A_InputSchema[Input: ExampleOneVarSchemaV1]\n    direction RL\n    STEP_A_InputSchemavar{{\"var::String\"}}\n    class STEP_A_InputSchemavar classSpecField\n  end\n  subgraph STEP_A_OutputSchema[Output: ExampleOneVarSchemaV1]\n    direction RL\n    STEP_A_OutputSchemavar{{\"var::String\"}}\n    class STEP_A_OutputSchemavar classSpecField\n  end\n  STEP_A_InputSchema:::classSpec -- fn_a --> STEP_A_OutputSchema:::classSpec\nend\nsubgraph STEP_B[Step b]\n  direction TB\n  subgraph STEP_B_InputSchema[Input: ExampleOneVarSchemaV1]\n    direction RL\n    STEP_B_InputSchemavar{{\"var::String\"}}\n    class STEP_B_InputSchemavar classSpecField\n  end\n  subgraph STEP_B_OutputSchema[Output: ExampleOneVarSchemaV1]\n    direction RL\n    STEP_B_OutputSchemavar{{\"var::String\"}}\n    class STEP_B_OutputSchemavar classSpecField\n  end\n  STEP_B_InputSchema:::classSpec -- fn_b --> STEP_B_OutputSchema:::classSpec\nend\nsubgraph STEP_C[Step c]\n  direction TB\n  subgraph STEP_C_InputSchema[Input: ExampleTwoVarSchemaV1]\n    direction RL\n    STEP_C_InputSchemavar1{{\"var1::String\"}}\n    class STEP_C_InputSchemavar1 classSpecField\n    STEP_C_InputSchemavar2{{\"var2::String\"}}\n    class STEP_C_InputSchemavar2 classSpecField\n  end\n  subgraph STEP_C_OutputSchema[Output: ExampleOneVarSchemaV1]\n    direction RL\n    STEP_C_OutputSchemavar{{\"var::String\"}}\n    class STEP_C_OutputSchemavar classSpecField\n  end\n  STEP_C_InputSchema:::classSpec -- fn_c --> STEP_C_OutputSchema:::classSpec\nend\n\n%% Link steps (edges)\nSTEP_A:::classStep -..-> STEP_B:::classStep\nSTEP_B:::classStep -..-> STEP_C:::classStep\n\nend\nOUTERLEVEL:::classOuter ~~~ OUTERLEVEL:::classOuter\n\n%% Styling definitions\nclassDef classOuter fill:#cbd7e2,stroke:#000,stroke-width:0px;\nclassDef classStep fill:#eeedff,stroke:#000,stroke-width:2px;\nclassDef classSpec fill:#f8f7ff,stroke:#000,stroke-width:1px;\nclassDef classSpecField fill:#fff,stroke:#000,stroke-width:1px;\n</div>","category":"page"},{"location":"","page":"Home","title":"Home","text":"Modules = [TransformSpecifications]\nPages = [\"mermaid.jl\"]\nPrivate = false","category":"page"},{"location":"#TransformSpecifications.mermaidify-Tuple{NoThrowDAG}","page":"Home","title":"TransformSpecifications.mermaidify","text":"mermaidify(dag::NoThrowDAG; direction=\"LR\",\n           style_step=\"fill:#eeedff,stroke:#000,stroke-width:2px;\",\n           style_spec=\"fill:#f8f7ff,stroke:#000,stroke-width:1px;\",\n           style_outer=\"fill:#cbd7e2,stroke:#000,stroke-width:0px;\",\n           style_spec_field=\"fill:#fff,stroke:#000,stroke-width:1px;\")\n\nGenerate mermaid plot of dag, suitable for inclusion in markdown documentation.\n\nArgs:\n\ndirection: option that specifies the orientation/flow of the dag's steps;   most useful options for dag plotting are LR (left to right) or TB (top to bottom);   see the mermaid documentation for full list of options.\nstyle_step: styling of the box containing an individual dag step (node)\nstyle_spec: styling of the boxes containing the input and output specifications for each step\nstyle_outer: styling of the box bounding the entire DAG\nstyle_spec_field: styling of the boxes bounding each specification's individual field(s)\n\nFor each style kwarg, see the mermaid documentation for style string options.\n\nTo include in markdown, do\n\n```mermaid\n{{mermaidify output}}\n```\n\nor for html (i.e., for Documenter.jl), do\n\n<div class=\"mermaid\">\n{{mermaidify output}}\n</div>\n\nFor an example of the raw output, see NoThrowDAG; for an example of the rendered output, see the built documentation.\n\n\n\n\n\n","category":"method"},{"location":"#TransformSpecifications-interface","page":"Home","title":"TransformSpecifications interface","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"TransformSpecifications provides a general interface which allows the creation of new subtypes of AbstractTransformSpecification that can be used to implement transformation.","category":"page"},{"location":"","page":"Home","title":"Home","text":"New transformation types must subtype AbstractTransformSpecification, and implement the following required methods.","category":"page"},{"location":"#Required-interface-type","page":"Home","title":"Required interface type","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"TransformSpecifications.AbstractTransformSpecification","category":"page"},{"location":"#TransformSpecifications.AbstractTransformSpecification","page":"Home","title":"TransformSpecifications.AbstractTransformSpecification","text":"abstract type AbstractTransformSpecification\n\nTransform specifications are represented by subtypes of AbstractTransformSpecification. Each leaf should be immutable and define methods for\n\ninput_specification returns type expected/allowed as transform input\noutput_specification returns output type generated by successfully completed processing\ntransform!, which transforms an input of type input_specification   and returns an output of type output_specification.\n\nIt may additionally define a custom non-mutating transform function.\n\n\n\n\n\n","category":"type"},{"location":"#Required-interface-methods","page":"Home","title":"Required interface methods","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"TransformSpecifications.transform!\nTransformSpecifications.input_specification\nTransformSpecifications.output_specification","category":"page"},{"location":"#TransformSpecifications.transform!","page":"Home","title":"TransformSpecifications.transform!","text":"transform!(ts::AbstractTransformSpecification, input)\n\nReturn result of applying ts to an input of type input_specification(ts), where result is an output_specification(ts). May mutate input.\n\nSee also: transform\n\n\n\n\n\n","category":"function"},{"location":"#TransformSpecifications.input_specification","page":"Home","title":"TransformSpecifications.input_specification","text":"input_specification(ts::AbstractTransformSpecification)\n\nReturn specification accepted as input to ts.\n\n\n\n\n\n","category":"function"},{"location":"#TransformSpecifications.output_specification","page":"Home","title":"TransformSpecifications.output_specification","text":"output_specification(ts::AbstractTransformSpecification)\n\nReturn specification of return value of ts.\n\n\n\n\n\n","category":"function"},{"location":"#Other-interface-methods","page":"Home","title":"Other interface methods","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"These methods have reasonable fallback definitions and should only be defined for new types if there is some reason to prefer a custom implementation over the default fallback.","category":"page"},{"location":"","page":"Home","title":"Home","text":"TransformSpecifications.transform","category":"page"},{"location":"#TransformSpecifications.transform","page":"Home","title":"TransformSpecifications.transform","text":"transform(ts::AbstractTransformSpecification, input)\n\nReturn result of applying ts to an input of type input_specification(ts), where result is an output_specification(ts). May not mutate input.\n\nSee also: transform!\n\n\n\n\n\n","category":"function"}]
}
