```@raw html
<script type="module">
  import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@9/dist/mermaid.esm.min.mjs';
  mermaid.initialize({ startOnLoad: true });
</script>
```
# Visualization

Here is the mermaid plot of the chain generated in [`NoThrowTransformChain`](@ref):

```@raw html
<div class="mermaid">
flowchart

%% Define steps (nodes)
subgraph OUTERLEVEL["` `"]
direction LR
subgraph STEP_A[Step a]
  direction TB
  subgraph STEP_A_InputSchema[Input: ExampleOneVarSchemaV1]
    direction RL
    STEP_A_InputSchemavar{{"var::String"}}
    class STEP_A_InputSchemavar classSpecField
  end
  subgraph STEP_A_OutputSchema[Output: ExampleOneVarSchemaV1]
    direction RL
    STEP_A_OutputSchemavar{{"var::String"}}
    class STEP_A_OutputSchemavar classSpecField
  end
  STEP_A_InputSchema:::classSpec -- fn_a --> STEP_A_OutputSchema:::classSpec
end
subgraph STEP_B[Step b]
  direction TB
  subgraph STEP_B_InputSchema[Input: ExampleOneVarSchemaV1]
    direction RL
    STEP_B_InputSchemavar{{"var::String"}}
    class STEP_B_InputSchemavar classSpecField
  end
  subgraph STEP_B_OutputSchema[Output: ExampleOneVarSchemaV1]
    direction RL
    STEP_B_OutputSchemavar{{"var::String"}}
    class STEP_B_OutputSchemavar classSpecField
  end
  STEP_B_InputSchema:::classSpec -- fn_b --> STEP_B_OutputSchema:::classSpec
end
subgraph STEP_C[Step c]
  direction TB
  subgraph STEP_C_InputSchema[Input: ExampleTwoVarSchemaV1]
    direction RL
    STEP_C_InputSchemavar1{{"var1::String"}}
    class STEP_C_InputSchemavar1 classSpecField
    STEP_C_InputSchemavar2{{"var2::String"}}
    class STEP_C_InputSchemavar2 classSpecField
  end
  subgraph STEP_C_OutputSchema[Output: ExampleOneVarSchemaV1]
    direction RL
    STEP_C_OutputSchemavar{{"var::String"}}
    class STEP_C_OutputSchemavar classSpecField
  end
  STEP_C_InputSchema:::classSpec -- fn_c --> STEP_C_OutputSchema:::classSpec
end

%% Link steps (edges)
STEP_A:::classStep -..-> STEP_B:::classStep
STEP_B:::classStep -..-> STEP_C:::classStep

end
OUTERLEVEL:::classOuter ~~~ OUTERLEVEL:::classOuter

%% Styling definitions
classDef classOuter fill:#cbd7e2,stroke:#000,stroke-width:0px;
classDef classStep fill:#eeedff,stroke:#000,stroke-width:2px;
classDef classSpec fill:#f8f7ff,stroke:#000,stroke-width:1px;
classDef classSpecField fill:#fff,stroke:#000,stroke-width:1px;

</div>
```

## Mermaid
```@autodocs
Modules = [TransformSpecifications]
Pages = ["mermaid.jl"]
Private = false
```
