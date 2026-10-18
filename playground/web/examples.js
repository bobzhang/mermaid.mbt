// One example per diagram type, from mermaid's documentation.
export const examples = [
 {
  "name": "Flowchart",
  "text": "flowchart RL\n    A@{ shape: manual-file, label: \"File Handling\"}\n    B@{ shape: manual-input, label: \"User Input\"}\n    C@{ shape: docs, label: \"Multiple Documents\"}\n    D@{ shape: procs, label: \"Process Automation\"}\n    E@{ shape: paper-tape, label: \"Paper Records\"}\n"
 },
 {
  "name": "Sequence",
  "text": "sequenceDiagram\n    participant API@{ \"type\": \"boundary\" } as Public API\n    actor DB@{ \"type\": \"database\" } as User Database\n    participant Svc@{ \"type\": \"control\" } as Auth Service\n    API->>Svc: Authenticate\n    Svc->>DB: Query user\n    DB-->>Svc: User data\n    Svc-->>API: Token\n"
 },
 {
  "name": "Class",
  "text": "classDiagram\nclassA --|> classB : Inheritance\nclassC --* classD : Composition\nclassE --o classF : Aggregation\nclassG --> classH : Association\nclassI -- classJ : Link(Solid)\nclassK ..> classL : Dependency\nclassM ..|> classN : Realization\nclassO .. classP : Link(Dashed)\n"
 },
 {
  "name": "State",
  "text": "stateDiagram\n    classDef yourState font-style:italic,font-weight:bold,fill:white\n\n    yswsii: Your state with spaces in it\n    [*] --> yswsii:::yourState\n    [*] --> SomeOtherState\n    SomeOtherState --> YetAnotherState\n    yswsii --> YetAnotherState\n    YetAnotherState --> [*]\n"
 },
 {
  "name": "Entity relationship",
  "text": "erDiagram\n    direction TB\n    CUSTOMER ||--o{ ORDER : places\n    CUSTOMER {\n        string name\n        string custNumber\n        string sector\n    }\n    ORDER ||--|{ LINE-ITEM : contains\n    ORDER {\n        int orderNumber\n        string deliveryAddress\n    }\n    LINE-ITEM {\n        string productCode\n        int quantity\n        float pricePerUnit\n    }\n"
 },
 {
  "name": "Gantt",
  "text": "gantt\n    title A Gantt Diagram\n    %% This is a comment\n    dateFormat YYYY-MM-DD\n    section Section\n        A task          :a1, 2014-01-01, 30d\n        Another task    :after a1, 20d\n    section Another\n        Task in Another :2014-01-12, 12d\n        another task    :24d\n"
 },
 {
  "name": "Pie",
  "text": "---\nconfig:\n  pie:\n    textPosition: 0.5\n    donutHole: 0.2\n    highlightSlice: Potassium\n  themeVariables:\n    pieOuterStrokeWidth: \"5px\"\n---\npie showData\n    title Key elements in Product X\n    \"Calcium\" : 42.96\n    \"Potassium\" : 50.05\n    \"Magnesium\" : 10.01\n    \"Iron\" :  5\n"
 },
 {
  "name": "Git graph",
  "text": "---\nconfig:\n  logLevel: 'debug'\n  theme: 'default'\n  themeVariables:\n      'git0': '#ff0000'\n      'git1': '#00ff00'\n      'git2': '#0000ff'\n      'git3': '#ff00ff'\n      'git4': '#00ffff'\n      'git5': '#ffff00'\n      'git6': '#ff00ff'\n      'git7': '#00ffff'\n---\n       gitGraph\n       commit\n       branch develop\n       commit tag:\"v1.0.0\"\n       commit\n       checkout main\n       commit type: HIGHLIGHT\n       commit\n       merge develop\n       commit\n       branch featureA\n       commit\n"
 },
 {
  "name": "User journey",
  "text": "journey\n    title My working day\n    section Go to work\n      Make tea: 5: Me\n      Go upstairs: 3: Me\n      Do work: 1: Me, Cat\n    section Go home\n      Go downstairs: 5: Me\n      Sit down: 5: Me\n"
 },
 {
  "name": "Timeline",
  "text": "timeline TD\n  title MermaidChart 2023 Timeline\n    section 2023 Q1 <br> Release Personal Tier\n      Bullet 1 : sub-point 1a : sub-point 1b\n      Bullet 2 : sub-point 2a : sub-point 2b\n    section 2023 Q2 <br> Release XYZ Tier\n      Bullet 3 : sub-point <br> 3a : sub-point 3b\n      Bullet 4 : sub-point 4a : sub-point 4b\n"
 },
 {
  "name": "Mindmap",
  "text": "---\nconfig:\n  theme: base\n  mindmap:\n    colorBy: depth\n  themeVariables:\n    git0: '#374151'\n    gitBranchLabel0: '#ffffff'\n    cScaleLabel0: '#ffffff'\n    cScale1: '#bfdbfe'\n    cScaleLabel1: '#172554'\n    cScale2: '#bbf7d0'\n    cScaleLabel2: '#14532d'\n    cScale3: '#fde68a'\n    cScaleLabel3: '#451a03'\n---\nmindmap\n  root((mindmap))\n    origins{{Origins}}\n      history[Long history]\n        Popularisation\n        British popular psychology author Tony Buzan\n    research{{Research}}\n      uses[Uses]\n        Creative techniques\n"
 },
 {
  "name": "Kanban",
  "text": "---\nconfig:\n  kanban:\n    ticketBaseUrl: 'https://mermaidchart.atlassian.net/browse/#TICKET#'\n---\nkanban\n  Todo\n    [Create Documentation]\n    docs[Create Blog about the new diagram]\n  [In progress]\n    id6[Create renderer so that it works in all cases. We also add some extra text here for testing purposes. And some more just for the extra flare.]\n  id9[Ready for deploy]\n    id8[Design grammar]@{ assigned: 'knsv' }\n  id10[Ready for test]\n    id4[Create parsing tests]@{ ticket: MC-2038, assigned: 'K.Sveidqvist', priority: 'High' }\n    id66[last item]@{ priority: 'Very Low', assigned: 'knsv' }\n  id11[Done]\n    id5[define getData]\n    id2[Title of diagram is more than 100 chars when user duplicates diagram with 100 char]@{ ticket: MC-2036, priority: 'Very High'}\n    id3[Update DB function]@{ ticket: MC-2037, assigned: knsv, priority: 'High' }\n\n  id12[Can't reproduce]\n    id3[Weird flickering in Firefox]\n"
 },
 {
  "name": "Block",
  "text": "block\n  blockArrowId<[\"Label\"]>(right)\n  blockArrowId2<[\"Label\"]>(left)\n  blockArrowId3<[\"Label\"]>(up)\n  blockArrowId4<[\"Label\"]>(down)\n  blockArrowId5<[\"Label\"]>(x)\n  blockArrowId6<[\"Label\"]>(y)\n  blockArrowId7<[\"Label\"]>(x, down)\n"
 },
 {
  "name": "C4",
  "text": "    C4Dynamic\n    title Dynamic diagram for Internet Banking System - API Application\n\n    ContainerDb(c4, \"Database\", \"Relational Database Schema\", \"Stores user registration information, hashed authentication credentials, access logs, etc.\")\n    Container(c1, \"Single-Page Application\", \"JavaScript and Angular\", \"Provides all of the Internet banking functionality to customers via their web browser.\")\n    Container_Boundary(b, \"API Application\") {\n      Component(c3, \"Security Component\", \"Spring Bean\", \"Provides functionality Related to signing in, changing passwords, etc.\")\n      Component(c2, \"Sign In Controller\", \"Spring MVC Rest Controller\", \"Allows users to sign in to the Internet Banking System.\")\n    }\n    Rel(c1, c2, \"Submits credentials to\", \"JSON/HTTPS\")\n    Rel(c2, c3, \"Calls isAuthenticated() on\")\n    Rel(c3, c4, \"select * from users where username = ?\", \"JDBC\")\n\n    UpdateRelStyle(c1, c2, $textColor=\"red\", $offsetY=\"-40\")\n    UpdateRelStyle(c2, c3, $textColor=\"red\", $offsetX=\"-40\", $offsetY=\"60\")\n    UpdateRelStyle(c3, c4, $textColor=\"red\", $offsetY=\"-40\", $offsetX=\"10\")\n"
 },
 {
  "name": "Quadrant chart",
  "text": "quadrantChart\n  title Reach and engagement of campaigns\n  x-axis Low Reach --> High Reach\n  y-axis Low Engagement --> High Engagement\n  quadrant-1 We should expand\n  quadrant-2 Need to promote\n  quadrant-3 Re-evaluate\n  quadrant-4 May be improved\n  Campaign A: [0.9, 0.0] radius: 12\n  Campaign B:::class1: [0.8, 0.1] color: #ff3300, radius: 10\n  Campaign C: [0.7, 0.2] radius: 25, color: #00ff33, stroke-color: #10f0f0\n  Campaign D: [0.6, 0.3] radius: 15, stroke-color: #00ff0f, stroke-width: 5px ,color: #ff33f0\n  Campaign E:::class2: [0.5, 0.4]\n  Campaign F:::class3: [0.4, 0.5] color: #0000ff\n  classDef class1 color: #109060\n  classDef class2 color: #908342, radius : 10, stroke-color: #310085, stroke-width: 10px\n  classDef class3 color: #f00fff, radius : 10\n"
 },
 {
  "name": "XY chart",
  "text": "xychart\n    title \"Sales Revenue\"\n    x-axis [jan, feb, mar, apr, may, jun, jul, aug, sep, oct, nov, dec]\n    y-axis \"Revenue (in $)\" 4000 --> 11000\n    bar [5000, 6000, 7500, 8200, 9500, 10500, 11000, 10200, 9200, 8500, 7000, 6000]\n    line [5000, 6000, 7500, 8200, 9500, 10500, 11000, 10200, 9200, 8500, 7000, 6000]\n"
 },
 {
  "name": "Sankey",
  "text": "---\nconfig:\n  sankey:\n    showValues: false\n    nodeWidth: 15\n    nodePadding: 20\n---\nsankey\n\nElectricity grid,Heating and cooling - homes,113.726\nElectricity grid,Industry,342.165\nElectricity grid,Losses,56.691\n"
 },
 {
  "name": "Radar",
  "text": "radar-beta\n  title Restaurant Comparison\n  axis food[\"Food Quality\"], service[\"Service\"], price[\"Price\"]\n  axis ambiance[\"Ambiance\"]\n\n  curve a[\"Restaurant A\"]{4, 3, 2, 4}\n  curve b[\"Restaurant B\"]{3, 4, 3, 3}\n  curve c[\"Restaurant C\"]{2, 3, 4, 2}\n  curve d[\"Restaurant D\"]{2, 2, 4, 3}\n\n  graticule polygon\n  max 5\n"
 },
 {
  "name": "Treemap",
  "text": "treemap-beta\n\"Products\"\n    \"Electronics\"\n        \"Phones\": 50\n        \"Computers\": 30\n        \"Accessories\": 20\n    \"Clothing\"\n        \"Men's\": 40\n        \"Women's\": 40\n"
 },
 {
  "name": "Requirement",
  "text": "requirementDiagram\n\nrequirement test_req:::important {\n    id: 1\n    text: \"class styling example\"\n    risk: low\n    verifymethod: test\n}\n\nelement test_entity {\n    type: simulation\n}\n\nclassDef important font-weight:bold\n\nclass test_entity important\nstyle test_entity fill:#f9f,stroke:#333\n"
 },
 {
  "name": "Architecture",
  "text": "architecture-beta\n    service left_disk(disk)[Disk]\n    service top_disk(disk)[Disk]\n    service bottom_disk(disk)[Disk]\n    service top_gateway(internet)[Gateway]\n    service bottom_gateway(internet)[Gateway]\n    junction junctionCenter\n    junction junctionRight\n\n    left_disk:R -- L:junctionCenter\n    top_disk:B -- T:junctionCenter\n    bottom_disk:T -- B:junctionCenter\n    junctionCenter:R -- L:junctionRight\n    top_gateway:B -- T:junctionRight\n    bottom_gateway:T -- B:junctionRight\n"
 },
 {
  "name": "Packet",
  "text": "---\nconfig:\n  packet:\n    showBits: true\n  themeVariables:\n    packet:\n      startByteColor: red\n---\npacket\n0-15: \"Source Port\"\n16-31: \"Destination Port\"\n32-63: \"Sequence Number\"\n"
 },
 {
  "name": "Venn",
  "text": "venn-beta\n  title What makes a good feature\n  set Desirable\n  set Feasible\n  set Viable\n  union Desirable,Feasible[\"Buildable\"]\n  union Feasible,Viable[\"Sustainable\"]\n  union Desirable,Viable[\"Marketable\"]\n  union Desirable,Feasible,Viable[\"Ship it\"]\n"
 },
 {
  "name": "Wardley map",
  "text": "wardley-beta\ntitle Dual Label Stages\n\nevolution Genesis / Concept -> Custom / Emerging -> Product / Converging -> Commodity / Accepted\n\ncomponent Novel Idea [0.05, 0.20]\ncomponent Custom Solution [0.35, 0.50]\ncomponent Product [0.65, 0.70]\ncomponent Utility [0.95, 0.90]\n"
 },
 {
  "name": "Railroad",
  "text": "railroad-peg-beta\ntitle \"Calculator Grammar\"\n\nExpression <- Term ((\"+\" / \"-\") Term)* ;\nTerm <- Factor ((\"*\" / \"/\") Factor)* ;\nFactor <- Number / \"(\" Expression \")\" ;\nNumber <- Digit+ ;\nDigit <- \"0\" / \"1\" / \"2\" / \"3\" / \"4\" / \"5\" / \"6\" / \"7\" / \"8\" / \"9\" ;\n"
 },
 {
  "name": "Event modeling",
  "text": "eventmodeling\n\ntimeframe 01 ui CartUI\ntimeframe 02 command AddItem\ntimeframe 03 event ItemAdded\n\nresetframe 04 event External.InventoryChanged\ntimeframe 05 processor InventoryProcessor\ntimeframe 06 command ChangeInventory\ntimeframe 07 event Cart.InventoryChanged\n"
 },
 {
  "name": "Cynefin",
  "text": "cynefin-beta\n  title Strategy Categorization\n\n  complex\n    \"Market research\"\n\n  complicated\n    \"Competitive analysis\"\n\n  clear\n    \"Standard pricing\"\n\n  chaotic\n    \"Crisis management\"\n\n  complex --> complicated : \"Pattern identified\"\n  complicated --> clear : \"Best practice codified\"\n  clear --> chaotic : \"Complacency\"\n  chaotic --> complex : \"Stabilized\"\n"
 },
 {
  "name": "Ishikawa",
  "text": "ishikawa-beta\n    Blurry Photo\n    Process\n        Out of focus\n        Shutter speed too slow\n        Protective film not removed\n        Beautification filter applied\n    User\n        Shaky hands\n    Equipment\n        LENS\n            Inappropriate lens\n            Damaged lens\n            Dirty lens\n        SENSOR\n            Damaged sensor\n            Dirty sensor\n    Environment\n        Subject moved too quickly\n        Too dark\n"
 },
 {
  "name": "Tree view",
  "text": "treeView-beta\n├── packages/\n│   ├── mermaid/\n│   │   ├── src/\n│   │   │   ├── parser.ts\n│   │   │   └── renderer.ts\n│   │   └── package.json\n│   └── parser/\n│       └── src/\n└── README.md\n"
 },
 {
  "name": "Use case",
  "text": "usecase-beta\naccTitle: Account access use cases\naccDescr {\n  A customer signs in and can reset a password.\n  The diagram names the actor, use cases, and associations.\n}\nactor Customer\nSignIn(\"Sign in\")\nReset(\"Reset password\")\nCustomer --> SignIn\nCustomer --> Reset\n"
 },
 {
  "name": "Agentflow",
  "text": "agentflow-beta TB\n  flow intake[\"Intake\"]\n    receive[\"Receive request\"]@{ shape: input }\n  end\n\n  flow processing[\"Processing\"]\n    validate[\"Validate\"]@{ shape: task }\n    enrich[\"Enrich\"]@{ shape: task }\n    validate --> enrich\n  end\n  processing@{ view: \"collapsed\" }\n\n  flow output[\"Output\"]\n    publish[\"Publish\"]@{ shape: action }\n  end\n\n  receive --> validate\n  enrich --> publish\n"
 },
 {
  "name": "Swimlanes",
  "text": "swimlane-beta LR\n  accTitle: Support escalation\n  accDescr: A request starts with the customer, is triaged by support, and may be escalated to engineering.\n\n  subgraph Customer\n    request[Open request]\n  end\n\n  subgraph Support\n    triage[Triage]\n  end\n\n  subgraph Engineering\n    resolve[Resolve]\n  end\n\n  request --> triage --> resolve\n"
 }
];
