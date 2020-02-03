# River Map Extraction from OpenStreetMap Data and Reconstruction

## Goal
We want to use our tool LOOM to render maps of rivers from OSM data. In the meantime, each river segment should consist of all rivers that contributed to this river so far, for example, beginning at Mannheim, the Neckar should be part of the segment that makes up the Rhine. In the end, each river will look like a single subway line starting at the source of the river, and the Rhine, for example, will look like dozens of small subway lines next to each other.


## Code structure

### Container

One of the major catches of this project is to store the river information extracted from OSM data properly. To fulfill this task, a class named `RiverGraph` with three private map attributes is created. Here is a table interpreting these attributes.

<table style="width:100%">
  <tr>
    <th colspan="5" style="background-color:rgba(0,0,0,.075);">Attributes of the class  <code>RiverGraph</code></th>
  </tr>
  <tr>
    <th>Name</th>
    <th>Meaning</th> 
    <th>Key</th> 
    <th>Type of Key</th>
    <th>Value</th>
  </tr>
  <tr>
    <td style='text-align:center;vertical-align:middle'>_nMap</td>
    <td style='text-align:center;vertical-align:middle'>Node map</td> 
    <td style='text-align:center;vertical-align:middle'>ID of nodes</td>
    <td style='text-align:center;vertical-align:middle'><code>uint64_t</code></td>
    <td style='text-align:center;vertical-align:middle'><code>RiverNode</code> instance</td>
  </tr>
  <tr>
    <td style='text-align:center;vertical-align:middle'>_eMap</td>
    <td style='text-align:center;vertical-align:middle'>Edge map</td> 
    <td style='text-align:center;vertical-align:middle'>ID of edges</td>
    <td style='text-align:center;vertical-align:middle'><code>uint64_t</code></td>
    <td style='text-align:center;vertical-align:middle'><code>RiverEdge</code> instance</td>
  </tr>
  <tr>
    <td style='text-align:center;vertical-align:middle'>_rMap</td>
    <td style='text-align:center;vertical-align:middle'>River map</td> 
    <td style='text-align:center;vertical-align:middle'>name of rivers</td>
    <td style='text-align:center;vertical-align:middle'><code>string</code></td>
    <td style='text-align:center;vertical-align:middle'><code>RiverName</code> instance</td>
  </tr>
</table>

As shown in the table, each of the map attributes has a class as it's value, that is: `RiverNode`, `RiverEdge` and `RiverName`. These classes store information for the corresponding node, edge or river. Now let's see which information is preserved in each of the class. First of all, the class `RiverNode`.

<table style="width:100%">
  <tr>
    <th colspan="3" style="background-color:rgba(0,0,0,.075);">Attributes of the class <code>RiverNode</code></th>
  </tr>
  <tr>
    <th>Name</th>
    <th>Meaning</th> 
    <th>Type</th>
  </tr>
  <tr>
    <td style='text-align:center;vertical-align:middle'>_lon</td>
    <td style='text-align:center;vertical-align:middle'>longitude</td> 
    <td style='text-align:center;vertical-align:middle'><code>double</code></td>
  </tr>
  <tr>
    <td style='text-align:center;vertical-align:middle'>_lat</td>
    <td style='text-align:center;vertical-align:middle'>latitude</td> 
    <td style='text-align:center;vertical-align:middle'><code>double</code></td>
  </tr>
  <tr>
    <td style='text-align:center;vertical-align:middle'>_eInN</td>
    <td style='text-align:center;vertical-align:middle'>edge in node</td> 
    <td style='text-align:center;vertical-align:middle'><code>unordered_set<uint64_t></code></td>
  </tr>
</table>

Except the longitude and latitude information of each node, the third attribute "edge in node" means the edge(s) using this node as a point in it. If the node is an intersection, there with be two or more objects in this set. This attribute will be especially useful when we come to distinguish which rivers are the upstream ones for the current river, but we will come back to this later in the methods part. Next let's find out which features are in the class `RiverEdge`.

<table style="width:100%">
  <tr>
    <th colspan="3" style="background-color:rgba(0,0,0,.075);">Attributes of the class <code>RiverEdge</code></th>
  </tr>
  <tr>
    <th>Name</th>
    <th>Meaning</th> 
    <th>Type</th>
  </tr>
  <tr>
    <td style='text-align:center;vertical-align:middle'>_eName</td>
    <td style='text-align:center;vertical-align:middle'>edge name</td> 
    <td style='text-align:center;vertical-align:middle'><code>string</code></td>
  </tr>
  <tr>
    <td style='text-align:center;vertical-align:middle'>_eType</td>
    <td style='text-align:center;vertical-align:middle'>edge type</td> 
    <td style='text-align:center;vertical-align:middle'><code>string</code></td>
  </tr>
  <tr>
    <td style='text-align:center;vertical-align:middle'>_nInE</td>
    <td style='text-align:center;vertical-align:middle'>node in edge</td> 
    <td style='text-align:center;vertical-align:middle'><code>deque<uint64_t></code></td>
  </tr>
  <tr>
    <td style='text-align:center;vertical-align:middle'>_rId</td>
    <td style='text-align:center;vertical-align:middle'>river id</td> 
    <td style='text-align:center;vertical-align:middle'><code>uint64_t</code></td>
  </tr>
  <tr>
    <td style='text-align:center;vertical-align:middle'>_rInE</td>
    <td style='text-align:center;vertical-align:middle'>river in edge</td> 
    <td style='text-align:center;vertical-align:middle'><code>unordered_set<uint64_t></code></td>
  </tr>
</table>

First we have the name and the type features stored as a string, and then we have "node in edge" which is the points describing the river line in flow direction, this information comes directly from OSM data. Edges with the same name and intersect with each other share the same "river id", which is different from the key id of the `RiverEdge`, in which each edge has of course unique key. This is a little bit tricky because in the practice we usually find out many rivers, especially the small ones having exactly the same name. In this case, we have to check if the edges associate with each other, directly or indirectly, in order to identify if they are the same river. We will discuss it further in the methods chapter. "River in edge" is the upstream rivers of the current edge, it stores the river ids, rather than key ids of `RiverEdge`. The last class we want to clarify is the `RiverName`.

<table style="width:100%">
  <tr>
    <th colspan="3" style="background-color:rgba(0,0,0,.075);">Attributes of the class <code>RiverName</code></th>
  </tr>
  <tr>
    <th>Name</th>
    <th>Meaning</th> 
    <th>Type</th>
  </tr>
  <tr>
    <td style='text-align:center;vertical-align:middle'>_eInR</td>
    <td style='text-align:center;vertical-align:middle'>edge in river</td> 
    <td style='text-align:center;vertical-align:middle'><code>unordered_set<uint64_t></code></td>
  </tr>
</table>

Here we have "edge in river" which contains the edge id of the rivers with the same name. Be aware, the edges here might not intersect with each other directly, or even appears in the two opposite corners of the map. That means, they can just be two irrelavant rivers sharing the same name. 



### Methods

We have 3 major jobs to process the data. One is to extract the needed information from OSM and to store it in the right place, which is operated by the class `OsmFilter`. The second one is to reconstruct the data so that we can known the relationship (upstream and downstream) of the rivers, this is processed by the class `DirectedGraph`. The last one is to output the data in the proper json form, which is done by the class `GeoJSON`.

#### 1. Data Extraction, class `OsmFilter`

As we all known, osm data has three kinds of elements: nodes, ways and relations. In the case of getting river map information, only the first two kinds are relavant. In this project, the osm data is filtered two times in the data extracting procedure. In the first round, the legit water ways, that is: *rivers*, *streams*, *canals*, *drains*, *ditchs* and *brooks* are distinguished and stored into the map `RiverEdge`, together with their names and the nodes describing the water ways. The id of these nodes are also stored into the map `RiverNode` as keys. In the second round, the geographical information (longitude and latitude) of the nodes in the map `RiverNode` is stored.

#### 2. Graph Construction, class `DirectedGraph`

In order to know which are the exact upstream rivers for different water ways, we try to build a directed graph from the extracted data via the following operations:

* Add in and out information

  As said in the container part, in the map `RiverNode`, we have a set for each node to store the edge(s) using this node. If there are multiple edges in it, then this node is an intersection point. In this part, for all the beginning points, ending points, as well as intersection points, we store the number of edges going in or out. For example, at the merging point of two rivers into one, the point has two rivers coming in and one going out. The beginning points has of course only one river going out and the ending points (for example, where the river meets the sea) has only one coming in.

* Cut edges

  At each intersection points, that is, at the point where two or more rivers meet, if there is an edge going through this point, then it will be cut into two. In this way the river map becomes a proper directed graph, so that the parent nodes (upstream rivers) can be digged out easily.

* Concatenation

  If there are only one river coming and one leaving at a particular intersection point, and these two rivers has the same name, then the two edges will be concatenated into one. We do this because in practice we found some rivers expressed as many successive pieces in the OSM data, and this makes the result rather untidy. Here are two screenshots representing the results before and after the concatenation.

  
  | ![image info](../../static/img/project_river_maps/Concatenation.jpg =347x200)| 
  |:--:| 
  |Before concatenating|
  
  | ![image info](../../static/img/project_river_maps/AfterConcatenation.jpg =347x175)| 
  |:--:| 
  |After concatenating|

* Add river names

  Here comes the last step, that is to add the river names of the upstream rivers to the downstream ones. We begin with the nodes with no incoming edges, that is, the sources of the rivers. We go in the downstream direction. Each time we add a name to a downstream river, we deduct the outgoing river number of the current node by one, and the incoming river number of the next node by one. The name will of course only be added when it does not exist in the upstream river name set yet. When all the intersection nodes have no outgoing river, then the name adding process complete. 

#### 3. Output, class `GeoJSON`

The output of this project is a json file, and the nodes in the map `RiverNode` and the edges in the map `RiverEdge` will be printed one by one.


## Future works

#### 1. Add length filter to the rivers

When the map becomes large, it is quite easy that a large river has hundreds of upstream rivers. For example, in the state of Hamburg, which is a rather small state of Germany, there are more than 500 upstream rivers in the river Elbe. In this case, it is almost impossible to use LOOM to render the result map. Actually, a map with maximum 20 parallel river lines is more practical for LOOM. Under this condition, a filtering mechanism can be quite useful to render large scale maps, and also to make the result map simple and elegant. 

Since the filtering mechanism influences the name adding process, the best approach to me is to add a length summing function right before it. Like the name adding function, the filter should check the rivers in the downstream direction and avoid removing rivers staying in the middle, since this will sabotage the consecutiveness of the rivers. In addition, a boolean flag should be added into the values of the `RiverEdge` map, indicating if or not the edge is kept by the filter. 

#### 2. Add colors to the edges

It will be nice if every uptream river has a unique color, so that one can observe it better from the source all the way to the sea. The color feature is already there in the output, but currently all of them are set to <font color="#0000ff">0000ff</font>, which is blue. To update this, another attribute about color should be added to the `RiverEdge` map.

