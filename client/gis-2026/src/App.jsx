import { useEffect, useRef } from 'react';
import 'ol/ol.css'
import Map from 'ol/Map';
import View from 'ol/View';
import { fromLonLat } from 'ol/proj';
import ImageLayer from 'ol/layer/Image';
import ImageWMS from 'ol/source/ImageWMS';
import apply from 'ol-mapbox-style';


export default function App() {
  const mapRef = useRef(null);

  useEffect(() => {
    fetch('/style.json')
      .then(response => response.json())
      .then(async style => {
        const map = new Map({
          target: mapRef.current,
          view: new View({
            center: fromLonLat([48.373, 53.208]),
            zoom: 15,
          }),
        });

        await apply(map, style);

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
          opacity: 0.5,
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

        map.addLayer(buildingsLayer);
        map.addLayer(roadsLayer);
      })
      .catch(err => console.error('Ошибка загрузки стиля:', err));
  }, []);

  return (
    <>
      <div ref={mapRef} className="map-container" />
      <div className="legend">
        <h4>Источник данных</h4>
        <div>
          <span className="legend-color my"></span>
          my
        </div>
        <div>
          <span className="legend-color osm"></span>
          osm
        </div>
        <div>
          <span className="legend-color ml"></span>
          ml
        </div>
      </div>
    </>
  );
}