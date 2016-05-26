import controlP5.*;
import ddf.minim.*;
import ddf.minim.analysis.*;
import java.util.*;
import java.net.InetAddress;
import javax.swing.*;
import ddf.minim.effects.*;
import ddf.minim.ugens.*;
import javax.swing.filechooser.FileFilter;
import javax.swing.filechooser.FileNameExtensionFilter;
import org.elasticsearch.action.admin.indices.exists.indices.IndicesExistsResponse;
import org.elasticsearch.action.admin.cluster.health.ClusterHealthResponse;
import org.elasticsearch.action.index.IndexRequest;
import org.elasticsearch.action.index.IndexResponse;
import org.elasticsearch.action.search.SearchResponse;
import org.elasticsearch.action.search.SearchType;
import org.elasticsearch.client.Client;
import org.elasticsearch.common.settings.Settings;
import org.elasticsearch.node.Node;
import org.elasticsearch.node.NodeBuilder;
ControlP5 cp5;
Minim minim;

FFT fft;
Textlabel texto;
boolean si;
static String INDEX_NAME = "canciones";
static String DOC_TYPE = "cancion";
AudioPlayer player;
AudioMetaData meta;
int duracion=0;
String cancionTitulo, cancionAutor;
Client client;
Node node;
ScrollableList list;
boolean nocancion=false;
void setup() {
  cp5 = new ControlP5(this);
  size(550, 550);
  minim =new Minim(this);
  cp5 = new ControlP5(this);
  cancionTitulo="No seleccion";
  cancionAutor="No seleccion";
  duracion=0;

  Settings.Builder settings = Settings.settingsBuilder();

  settings.put("path.data", "esdata");
  settings.put("path.home", "/");
  settings.put("http.enabled", false);
  settings.put("index.number_of_replicas", 0);
  settings.put("index.number_of_shards", 1);
  node = NodeBuilder.nodeBuilder()
    .settings(settings)
    .clusterName("mycluster")
    .data(true)
    .local(true)
    .node();
  // Instancia de cliente de conexion al nodo de ElasticSearch
  client = node.client();

  // Esperamos a que el nodo este correctamente inicializado
  ClusterHealthResponse r = client.admin().cluster().prepareHealth().setWaitForGreenStatus().get();
  println(r);

  // Revisamos que nuestro indice (base de datos) exista
  IndicesExistsResponse ier = client.admin().indices().prepareExists(INDEX_NAME).get();
  if (!ier.isExists()) {
    // En caso contrario, se crea el indice
    client.admin().indices().prepareCreate(INDEX_NAME).get();
  }
  textFont(createFont("Serif", 12));
  cp5.addButton("play")
    .setPosition(100, 100)
    .setSize(50, 50)
    ;
  cp5.addButton("pausa")
    .setValue(0)
    .setPosition(200, 100)
    .setSize(50, 50)
    ;
  cp5.addButton("stop")
    .setValue(0)
    .setPosition(150, 100)
    .setSize(50, 50)
    ;
  cp5.addButton("cargar")
    .setPosition(250, 100)
    .setSize(50, 50)
    ;
  cp5.addSlider("volumen")
    .setValue(100)
    .setRange(0, 100)
    .setSize(200, 30)
    .setPosition(100, 150);
  cp5.addSlider("Balance")
    .setValue(100)
    .setRange(-50, 100)
    .setSize(200, 30)
    .setPosition(100, 200);
  cp5.addSlider("Pan")
    .setValue(0)
    .setRange(-1, 1)
    .setSize(200, 30)
    .setPosition(100, 230);
  list = cp5.addScrollableList("playlist")
    .setPosition(0, 250)
    .setSize(500, 300)
    .setBarHeight(20)
    .setItemHeight(20)
    .setType(ScrollableList.LIST);
}
int ys = 25;
int yi = 15;
float x=100, y=100, w=0;
void draw() {
  background(0);
  int y = ys;
  text("Titulo: " + cancionTitulo, 200, y+=yi); 
  text("Autor: " + cancionAutor, 200, y+=yi);
  stuff() ;
  volumen();
}
public void play() {
  player.play();
  meta=player.getMetaData();
  cancionTitulo=meta.title();
  cancionAutor=meta.author();
  duracion=player.length();
  fft = new FFT(player.bufferSize(), player.sampleRate());
}



public void stop() {
  player.pause();
  player.rewind();
}
public void pausa() {
  player.pause();
}





public void fileSelected(File selection) {
  if (selection == null) {
    println("Seleccion cancelada");
  } else {
    println("User selected " + selection.getAbsolutePath());
    player = minim.loadFile(selection.getAbsolutePath(), 1024);
  }
}

public void cargar() {

  // Selector de archivos
  JFileChooser jfc = new JFileChooser();
  // Agregamos filtro para seleccionar solo archivos .mp3
  jfc.setFileFilter(new FileNameExtensionFilter("MP3 File", "mp3"));
  // Se permite seleccionar multiples archivos a la vez
  jfc.setMultiSelectionEnabled(true);
  // Abre el dialogo de seleccion
  jfc.showOpenDialog(null);

  // Iteramos los archivos seleccionados
  for (File f : jfc.getSelectedFiles()) {
    // Si el archivo ya existe en el indice, se ignora
    GetResponse response = client.prepareGet(INDEX_NAME, DOC_TYPE, f.getAbsolutePath()).setRefresh(true).execute().actionGet();
    if (response.isExists()) {
      continue;
    }

    // Cargamos el archivo en la libreria minim para extrar los metadatos
    Minim minim = new Minim(this);
    AudioPlayer player = minim.loadFile(f.getAbsolutePath());
        AudioMetaData meta = player.getMetaData();


    // Almacenamos los metadatos en un hashmap
    Map<String, Object> doc = new HashMap<String, Object>();
    doc.put("author", meta.author());
    doc.put("title", meta.title());
    doc.put("path", f.getAbsolutePath());

    try {
      client.prepareIndex(INDEX_NAME, DOC_TYPE, f.getAbsolutePath())
        .setSource(doc)
        .execute()
        .actionGet();
      // Agregamos el archivo a la lista
      addItem(doc);
    } 
    catch(Exception e) {
      e.printStackTrace();
    }
  }


  player.pause();
  player.rewind();
}
void stuff() {

  if (!nocancion) {
    if (!(fft==null)) {
      fft.forward(player.mix);
      stroke(255, 0, 0, 128);

      for (int i = 0; i < fft.specSize(); i++)
      {
        line(i, height, i, height - fft.getBand(i)*4);
      }
    }
    //
    fill(255);
    try {
      text (
        "Reproduciendo "
        + strFromMillis ( player.position() ) 
        + " de "
        + strFromMillis ( duracion ) 
        + ".", 
        200, 25 );

      if (!player.isPlaying()) {
        fill(255);
        text ("Pausa", 250, 95);
      } // if
    } // try
    catch (Exception e) {
      // e.printStackTrace();
    }
    finally {
    }
  }
}

String strFromMillis ( int m ) {

  float sec;
  int min;
  //
  sec = m / 1000;
  min = floor(sec / 60); 
  sec = floor(sec % 60);
  if (min>59) {
    int hrs = floor(min / 60);
    min = floor (min % 60);
    return  hrs+":"+nf(min, 2)+":"+nf(int(sec), 2);
  } else
  {
    return min+":"+nf(int(sec), 2);
  }
}
public void volumen() {
  x=cp5.getController("volumen").getValue();
  println(x);
  try {
    player.setGain(x-30);
  }  
  catch(Exception e) {
  }  

  y=cp5.getController("Balance").getValue();
  println(x);
  try {
    player.setBalance(y);
  }  
  catch(Exception e) {
  }  

  w=cp5.getController("Pan").getValue();
  try {
    player.setPan(w);
  }  
  catch(Exception e) {
  }
}

void playlist(int n) {
  println(list.getItem(n));
  //println(list.getItem(n));
  if (player!=null) {
    player.pause();
  }
  Map<String, Object> value = (Map<String, Object>) list.getItem(n).get("value");
  println(value.get("path"));
  minim = new Minim(this);

  player = minim.loadFile((String)value.get("path"), 1024);
  fft = new FFT(player.bufferSize(), player.sampleRate());
  // calculate averages based on a miminum octave width of 22 Hz
  // split each octave into three bands
  fft.logAverages(22, 10);
  meta = player.getMetaData();
  if (!meta.title().equals("")) {
    texto.setText(meta.title()+"`\n"+meta.author());
    print("sale");
  } else {
    texto.setText(meta.fileName());
    print("entra");
  }
}
void loadFiles() {
  try {
    // Buscamos todos los documentos en el indice
    SearchResponse response = client.prepareSearch(INDEX_NAME).execute().actionGet();

    // Se itera los resultados
    for (SearchHit hit : response.getHits().getHits()) {
      // Cada resultado lo agregamos a la lista
      addItem(hit.getSource());
    }
  } 
  catch(Exception e) {
    e.printStackTrace();
  }
}
void addItem(Map<String, Object> doc) {
  // Se agrega a la lista. El primer argumento es el texto a desplegar en la lista, el segundo es el objeto que queremos que almacene
  list.addItem(doc.get("author") + " - " + doc.get("title"), doc);
}