package com.smartcity.backend;

import com.uber.h3core.util.LatLng;
import org.example.Graph.Element.Point;
public class GeoUtil {

    public static double[] toXYZ(double lat, double lon) {
        double latRad = Math.toRadians(lat);
        double lonRad = Math.toRadians(lon);

        double x = Math.cos(latRad) * Math.cos(lonRad);
        double y = Math.cos(latRad) * Math.sin(lonRad);
        double z = Math.sin(latRad);

        return new double[]{x, y, z};
    }

    public static LatLng toLatLon(double x, double y, double z) {
        double latRad = Math.asin(z);
        double lonRad = Math.atan2(y, x);

        return new LatLng(
                Math.toDegrees(latRad),
                Math.toDegrees(lonRad)
        );
    }

    public static double[] normalize(double x, double y, double z) {
        double length = Math.sqrt(x * x + y * y + z * z);

        return new double[]{
                x / length,
                y / length,
                z / length
        };
    }

    public static LatLng fromXYZToLatLng(double x, double y, double z) {
        double[] norm = normalize(x, y, z);
        return toLatLon(norm[0], norm[1], norm[2]);
    }

    public static Double getEdgeCost(Point source , Point target){
        return getEdgeCost(source.getLat() , source.getLon() ,target.getLat() ,target.getLon());
    }
    public static Double getEdgeCost(Double lat1,Double lon1,Double lat2,Double lon2) {
        lat1 = Math.toRadians(lat1);
        lon1 = Math.toRadians(lon1);
        lat2 = Math.toRadians(lat2);
        lon2 = Math.toRadians(lon2);
        double dLat = (lat2 - lat1);
        double dLon = (lon2 - lon1);

        double a = Math.pow(Math.sin(dLat / 2), 2) +
                Math.pow(Math.sin(dLon / 2), 2) *
                        Math.cos(lat1) *
                        Math.cos(lat2);
        double rad = 6371;
        double c = 2 * Math.asin(Math.sqrt(a));

        return rad * c;
    }
}
