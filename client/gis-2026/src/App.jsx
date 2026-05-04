import { useEffect, useRef } from 'react';
import Map from 'ol/Map';
import View from 'ol/View';
import TileLayer from 'ol/layer/Tile';
import ImageLayer from 'ol/layer/Image';
import OSM from 'ol/source/OSM';
import ImageWMS from 'ol/source/ImageWMS';
import { fromLonLat } from 'ol/proj';
import 'ol/ol.css';


export default function App() {
  const mapRef = useRef(null);

  useEffect(() => {
    const osmLayer = new TileLayer({
      source: new OSM(),
    });

    const buildingsLayer = new ImageLayer({
      source: new ImageWMS({
        url: 'http://localhost:8080/geoserver/gis/wms',
        params: {
          LAYERS: 'gis:buildings',
          TILED: true,
        },
        ratio: 1,
        serverType: 'geoserver',
      }),
    });

    const roadsLayer = new ImageLayer({
      source: new ImageWMS({
        url: 'http://localhost:8080/geoserver/gis/wms',
        params: {
          LAYERS: 'gis:roads',
          TILED: true,
        },
        ratio: 1,
        serverType: 'geoserver',
      }),
    });

    const map = new Map({
      target: mapRef.current,
      layers: [
        osmLayer,
        buildingsLayer,
        roadsLayer,
      ],
      view: new View({
        center: fromLonLat([48.373, 53.208]), 
        zoom: 15,
      }),
    });

    return () => map.setTarget(null);
  }, []);

  return (
    <div
      ref={mapRef}
      style={{ width: '100vw', height: '100vh' }}
    />
  );
}