vec3 srgbToLinear(vec3 srgb){
    return mix(
        srgb / 12.92,
        pow(.947867 * srgb + .0521327, vec3(2.4) ),
        step( .04045, srgb )
    );
}

vec3 linearToSRGB(vec3 linear){
    return mix(
        linear * 12.92,
        pow(linear, vec3(1./2.4) ) * 1.055 - .055,
        step( .0031308, linear )
    );
}
