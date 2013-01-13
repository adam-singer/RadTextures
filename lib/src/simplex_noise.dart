part of rad_textures;

// CqNoise1234
// Copyright (C) 2003-2012, Stefan Gustavson
//
// Ported by: John Davis
// Contact: stegu@itn.liu.se, jdavis@pcprogramming.com
//
// This library is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
//
// This library is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// General Public License for more details.
//
// You should have received a copy of the GNU General Public
// License along with this library; if not, write to the Free Software
// Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

/** For the original versions see aqsis repo.  This is simply a port of the
    simplex noise functions in aqsis.
*/

/** \file
    \brief Implements the CqNoise1234 class for producing Perlin noise.
    \author Stefan Gustavson (stegu@itn.liu.se)
*/

/*
 * This implementation is "Improved Noise" as presented by
 * Ken Perlin at Siggraph 2002. The 3D function is a direct port
 * of his Java reference code available on www.noisemachine.com
 * (although I cleaned it up and made the code more readable),
 * but the 1D, 2D and 4D cases were implemented from scratch
 * by me.
 *
 * This is a highly reusable class. It has no dependencies
 * on any other file, apart from its own header file.
 */


// This is the new and improved, C(2) continuous interpolant
num FADE(num t) { return (t * t * t * ( t * ( t * 6 - 15 ) + 10 )); }

num FASTFLOOR(num x) { return (x>0) ? x.floor() : (x-1).floor(); }
num NLERP(num t, num a, num b) { return (a + t*(b-a)); }

//---------------------------------------------------------------------
// Static data

/*
 * Permutation table. This is just a random jumble of all numbers 0-255,
 * repeated twice to avoid wrapping the index at 255 for each lookup.
 * This needs to be exactly the same for all instances on all platforms,
 * so it's easiest to just keep it as static explicit data.
 * This also removes the need for any initialisation of this class.
 *
 * Note that making this an int[] instead of a char[] might make the
 * code run faster on platforms with a high penalty for unaligned single
 * byte addressing. Intel x86 is generally single-byte-friendly, but
 * some other CPUs are faster with 4-aligned reads.
 * However, a char[] is smaller, which avoids cache trashing, and that
 * is probably the most important aspect on most architectures.
 * This array is accessed a *lot* by the noise functions.
 * A vector-valued noise over 3D accesses it 96 times, and a
 * float-valued 4D noise 64 times. We want this to fit in the cache!
 */
class CqNoise {
    List<int> perm = [
		      151,160,137,91,90,15,
		      131,13,201,95,96,53,194,233,7,225,140,36,103,30,69,142,8,99,37,240,21,10,23,
		      190, 6,148,247,120,234,75,0,26,197,62,94,252,219,203,117,35,11,32,57,177,33,
		      88,237,149,56,87,174,20,125,136,171,168, 68,175,74,165,71,134,139,48,27,166,
		      77,146,158,231,83,111,229,122,60,211,133,230,220,105,92,41,55,46,245,40,244,
		      102,143,54, 65,25,63,161, 1,216,80,73,209,76,132,187,208, 89,18,169,200,196,
		      135,130,116,188,159,86,164,100,109,198,173,186, 3,64,52,217,226,250,124,123,
		      5,202,38,147,118,126,255,82,85,212,207,206,59,227,47,16,58,17,182,189,28,42,
		      223,183,170,213,119,248,152, 2,44,154,163, 70,221,153,101,155,167, 43,172,9,
		      129,22,39,253, 19,98,108,110,79,113,224,232,178,185, 112,104,218,246,97,228,
		      251,34,242,193,238,210,144,12,191,179,162,241, 81,51,145,235,249,14,239,107,
		      49,192,214, 31,181,199,106,157,184, 84,204,176,115,121,50,45,127, 4,150,254,
		      138,236,205,93,222,114,67,29,24,72,243,141,128,195,78,66,215,61,156,180,
		      151,160,137,91,90,15,
		      131,13,201,95,96,53,194,233,7,225,140,36,103,30,69,142,8,99,37,240,21,10,23,
		      190, 6,148,247,120,234,75,0,26,197,62,94,252,219,203,117,35,11,32,57,177,33,
		      88,237,149,56,87,174,20,125,136,171,168, 68,175,74,165,71,134,139,48,27,166,
		      77,146,158,231,83,111,229,122,60,211,133,230,220,105,92,41,55,46,245,40,244,
		      102,143,54, 65,25,63,161, 1,216,80,73,209,76,132,187,208, 89,18,169,200,196,
		      135,130,116,188,159,86,164,100,109,198,173,186, 3,64,52,217,226,250,124,123,
		      5,202,38,147,118,126,255,82,85,212,207,206,59,227,47,16,58,17,182,189,28,42,
		      223,183,170,213,119,248,152, 2,44,154,163, 70,221,153,101,155,167, 43,172,9,
		      129,22,39,253, 19,98,108,110,79,113,224,232,178,185, 112,104,218,246,97,228,
		      251,34,242,193,238,210,144,12,191,179,162,241, 81,51,145,235,249,14,239,107,
		      49,192,214, 31,181,199,106,157,184, 84,204,176,115,121,50,45,127, 4,150,254,
		      138,236,205,93,222,114,67,29,24,72,243,141,128,195,78,66,215,61,156,180
		      ];

    //---------------------------------------------------------------------

    /*
     * Helper functions to compute gradients-dot-residualvectors (1D to 4D)
     * Note that these generate gradients of more than unit length. To make
     * a close match with the value range of classic Perlin noise, the final
     * noise values need to be rescaled. To match the RenderMan noise in a
     * statistical sense, the approximate scaling values (empirically
     * determined from test renderings) are:
     * 1D noise needs rescaling with 0.188
     * 2D noise needs rescaling with 0.507
     * 3D noise needs rescaling with 0.936
     * 4D noise needs rescaling with 0.87
     * Note that these noise functions are the most practical and useful
     * signed version of Perlin noise. To return values according to the
     * RenderMan specification from the SL noise() and pnoise() functions,
     * the noise values need to be scaled and offset to [0,1], like this:
     * float SLnoise = (CqNoise1234::noise(x,y,z) + 1.0) * 0.5;
     */

    num grad1(num hash, num x)
    {
	int h = hash & 15;
	num grad = 1.0 + (h & 7);  // Gradient value 1.0, 2.0, ..., 8.0
	if ((h & 8) != 0) {
	    grad = -grad;
	}         // and a random sign for the gradient
	return ( grad * x );           // Multiply the gradient with the distance
    }

    num grad2(num hash, num x, num y)
    {
	int h = hash & 7;      // Convert low 3 bits of hash code
	int u = h<4 ? x : y;  // into 8 simple gradient directions,
	int v = h<4 ? y : x;  // and compute the dot product with (x,y).
	return ((h & 1) != 0 ? -u : u) + ((h & 2) != 0 ? -2.0 * v : 2.0 * v);
    }

    num grad3(num hash, num x, num y , num z)
    {
	int h = hash & 15;     // Convert low 4 bits of hash code into 12 simple
	num u = h<8 ? x : y; // gradient directions, and compute dot product.
	num v = h<4 ? y : h==12||h==14 ? x : z; // Fix repeats at h = 12 to 15
	return ((h & 1) != 0 ? -u : u) + ((h & 2) != 0 ? -v : v);
    }

    num grad4(num hash, num x, num y, num z, num t)
    {
	int h = hash & 31;      // Convert low 5 bits of hash code into 32 simple
	num u = h<24 ? x : y; // gradient directions, and compute dot product.
	num v = h<16 ? y : z;
	num w = h<8 ? z : t;
	return ((h & 1) != 0 ? -u : u) + ((h & 2) != 0 ? -v : v) + ((h & 4) != 0 ? -w : w);
    }

    //---------------------------------------------------------------------
    /** 1D float Perlin noise, SL "noise()"
     */
    num noise1(x)
    {
	num ix0, ix1;
	num fx0, fx1;
	num s, n0, n1;

	ix0 = FASTFLOOR( x ); // Integer part of x
	fx0 = x - ix0;       // Fractional part of x
	fx1 = fx0 - 1.0;
	ix1 = ( ix0+1 ) & 0xff;
	ix0 = ix0 & 0xff;    // Wrap to 0..255

	s = FADE( fx0 );

	n0 = this.grad1( this.perm[ ix0 ], fx0 );
	n1 = this.grad1( this.perm[ ix1 ], fx1 );
	return 0.188 * ( NLERP( s, n0, n1 ) );
    }

    //---------------------------------------------------------------------
    /** 1D float Perlin periodic noise, SL "pnoise()"
     */
    num pnoise1(num x, num px)
    {
	num ix0, ix1;
	num fx0, fx1;
	num s, n0, n1;

	ix0 = FASTFLOOR( x ); // Integer part of x
	fx0 = x - ix0;       // Fractional part of x
	fx1 = fx0 - 1.0;
	if (px < 1) px = 1;
	ix1 = (( ix0 + 1 ) % px) & 0xff; // Wrap to 0..px-1 *and* wrap to 0..255
	ix0 = ( ix0 % px ) & 0xff;      // (because px might be greater than 256)

	s = FADE( fx0 );

	n0 = this.grad1( this.perm[ ix0 ], fx0 );
	n1 = this.grad1( this.perm[ ix1 ], fx1 );
	return 0.188 * ( NLERP( s, n0, n1 ) );
    }


    //---------------------------------------------------------------------
    /** 2D float Perlin noise.
     */
    num noise2(num x, num y)
    {
	num ix0, iy0, ix1, iy1;
	num fx0, fy0, fx1, fy1;
	num s, t, nx0, nx1, n0, n1;

	ix0 = FASTFLOOR( x ); // Integer part of x
	iy0 = FASTFLOOR( y ); // Integer part of y
	fx0 = x - ix0;        // Fractional part of x
	fy0 = y - iy0;        // Fractional part of y
	fx1 = fx0 - 1.0;
	fy1 = fy0 - 1.0;
	ix1 = (ix0 + 1) & 0xff;  // Wrap to 0..255
	iy1 = (iy0 + 1) & 0xff;
	ix0 = ix0 & 0xff;
	iy0 = iy0 & 0xff;

	t = FADE( fy0 );
	s = FADE( fx0 );

	nx0 = this.grad2(this.perm[ix0 + this.perm[iy0]], fx0, fy0);
	nx1 = this.grad2(this.perm[ix0 + this.perm[iy1]], fx0, fy1);
	n0 = NLERP( t, nx0, nx1 );

	nx0 = this.grad2(this.perm[ix1 + this.perm[iy0]], fx1, fy0);
	nx1 = this.grad2(this.perm[ix1 + this.perm[iy1]], fx1, fy1);
	n1 = NLERP(t, nx0, nx1);

	return 0.507 * ( NLERP( s, n0, n1 ) );
    }

    //---------------------------------------------------------------------
    /** 2D float Perlin periodic noise.
     */
    num pnoise2(x, y, px, py)
    {
	num ix0, iy0, ix1, iy1;
	num fx0, fy0, fx1, fy1;
	num s, t, nx0, nx1, n0, n1;

	ix0 = FASTFLOOR( x ); // Integer part of x
	iy0 = FASTFLOOR( y ); // Integer part of y
	fx0 = x - ix0;        // Fractional part of x
	fy0 = y - iy0;        // Fractional part of y
	fx1 = fx0 - 1.0;
	fy1 = fy0 - 1.0;
	if (px < 1) px = 1;
	if (py < 1) py = 1;
	ix1 = (( ix0 + 1 ) % px) & 0xff;  // Wrap to 0..px-1 and wrap to 0..255
	iy1 = (( iy0 + 1 ) % py) & 0xff;  // Wrap to 0..py-1 and wrap to 0..255
	ix0 = ( ix0 % px ) & 0xff;
	iy0 = ( iy0 % py ) & 0xff;

	t = FADE( fy0 );
	s = FADE( fx0 );

	nx0 = this.grad2(this.perm[ix0 + this.perm[iy0]], fx0, fy0);
	nx1 = this.grad2(this.perm[ix0 + this.perm[iy1]], fx0, fy1);
	n0 = NLERP( t, nx0, nx1 );

	nx0 = this.grad2(this.perm[ix1 + this.perm[iy0]], fx1, fy0);
	nx1 = this.grad2(this.perm[ix1 + this.perm[iy1]], fx1, fy1);
	n1 = NLERP(t, nx0, nx1);

	return 0.507 * ( NLERP( s, n0, n1 ) );
    }


    //---------------------------------------------------------------------
    /** 3D float Perlin noise.
     */
    num noise3(num x, num y, num z)
    {
	num ix0, iy0, ix1, iy1, iz0, iz1;
	num fx0, fy0, fz0, fx1, fy1, fz1;
	num s, t, r;
	num nxy0, nxy1, nx0, nx1, n0, n1;

	ix0 = FASTFLOOR( x ); // Integer part of x
	iy0 = FASTFLOOR( y ); // Integer part of y
	iz0 = FASTFLOOR( z ); // Integer part of z
	fx0 = x - ix0;        // Fractional part of x
	fy0 = y - iy0;        // Fractional part of y
	fz0 = z - iz0;        // Fractional part of z
	fx1 = fx0 - 1.0;
	fy1 = fy0 - 1.0;
	fz1 = fz0 - 1.0;
	ix1 = ( ix0 + 1 ) & 0xff; // Wrap to 0..255
	iy1 = ( iy0 + 1 ) & 0xff;
	iz1 = ( iz0 + 1 ) & 0xff;
	ix0 = ix0 & 0xff;
	iy0 = iy0 & 0xff;
	iz0 = iz0 & 0xff;

	r = FADE( fz0 );
	t = FADE( fy0 );
	s = FADE( fx0 );

	nxy0 = this.grad3(this.perm[ix0 + this.perm[iy0 + this.perm[iz0]]], fx0, fy0, fz0);
	nxy1 = this.grad3(this.perm[ix0 + this.perm[iy0 + this.perm[iz1]]], fx0, fy0, fz1);
	nx0 = NLERP( r, nxy0, nxy1 );

	nxy0 = this.grad3(this.perm[ix0 + this.perm[iy1 + this.perm[iz0]]], fx0, fy1, fz0);
	nxy1 = this.grad3(this.perm[ix0 + this.perm[iy1 + this.perm[iz1]]], fx0, fy1, fz1);
	nx1 = NLERP( r, nxy0, nxy1 );

	n0 = NLERP( t, nx0, nx1 );

	nxy0 = this.grad3(this.perm[ix1 + this.perm[iy0 + this.perm[iz0]]], fx1, fy0, fz0);
	nxy1 = this.grad3(this.perm[ix1 + this.perm[iy0 + this.perm[iz1]]], fx1, fy0, fz1);
	nx0 = NLERP( r, nxy0, nxy1 );

	nxy0 = this.grad3(this.perm[ix1 + this.perm[iy1 + this.perm[iz0]]], fx1, fy1, fz0);
	nxy1 = this.grad3(this.perm[ix1 + this.perm[iy1 + this.perm[iz1]]], fx1, fy1, fz1);
	nx1 = NLERP( r, nxy0, nxy1 );

	n1 = NLERP( t, nx0, nx1 );

	return 0.936 * ( NLERP( s, n0, n1 ) );
    }

    //---------------------------------------------------------------------
    /** 3D float Perlin periodic noise.
     */
    num pnoise3(num x, num y, num z, num px, num py, num pz)
    {
	num ix0, iy0, ix1, iy1, iz0, iz1;
	num fx0, fy0, fz0, fx1, fy1, fz1;
	num s, t, r;
	num nxy0, nxy1, nx0, nx1, n0, n1;

	ix0 = FASTFLOOR( x ); // Integer part of x
	iy0 = FASTFLOOR( y ); // Integer part of y
	iz0 = FASTFLOOR( z ); // Integer part of z
	fx0 = x - ix0;        // Fractional part of x
	fy0 = y - iy0;        // Fractional part of y
	fz0 = z - iz0;        // Fractional part of z
	fx1 = fx0 - 1.0;
	fy1 = fy0 - 1.0;
	fz1 = fz0 - 1.0;
	if (px < 1) px = 1;
	if (py < 1) py = 1;
	if (pz < 1) pz = 1;
	ix1 = (( ix0 + 1 ) % px ) & 0xff; // Wrap to 0..px-1 and wrap to 0..255
	iy1 = (( iy0 + 1 ) % py ) & 0xff; // Wrap to 0..py-1 and wrap to 0..255
	iz1 = (( iz0 + 1 ) % pz ) & 0xff; // Wrap to 0..pz-1 and wrap to 0..255
	ix0 = ( ix0 % px ) & 0xff;
	iy0 = ( iy0 % py ) & 0xff;
	iz0 = ( iz0 % pz ) & 0xff;

	r = FADE( fz0 );
	t = FADE( fy0 );
	s = FADE( fx0 );

	nxy0 = this.grad3(this.perm[ix0 + this.perm[iy0 + this.perm[iz0]]], fx0, fy0, fz0);
	nxy1 = this.grad3(this.perm[ix0 + this.perm[iy0 + this.perm[iz1]]], fx0, fy0, fz1);
	nx0 = NLERP( r, nxy0, nxy1 );

	nxy0 = this.grad3(this.perm[ix0 + this.perm[iy1 + this.perm[iz0]]], fx0, fy1, fz0);
	nxy1 = this.grad3(this.perm[ix0 + this.perm[iy1 + this.perm[iz1]]], fx0, fy1, fz1);
	nx1 = NLERP( r, nxy0, nxy1 );

	n0 = NLERP( t, nx0, nx1 );

	nxy0 = this.grad3(this.perm[ix1 + this.perm[iy0 + this.perm[iz0]]], fx1, fy0, fz0);
	nxy1 = this.grad3(this.perm[ix1 + this.perm[iy0 + this.perm[iz1]]], fx1, fy0, fz1);
	nx0 = NLERP( r, nxy0, nxy1 );

	nxy0 = this.grad3(this.perm[ix1 + this.perm[iy1 + this.perm[iz0]]], fx1, fy1, fz0);
	nxy1 = this.grad3(this.perm[ix1 + this.perm[iy1 + this.perm[iz1]]], fx1, fy1, fz1);
	nx1 = NLERP( r, nxy0, nxy1 );

	n1 = NLERP( t, nx0, nx1 );

	return 0.936 * ( NLERP( s, n0, n1 ) );
    }


    //---------------------------------------------------------------------
    /** 4D float Perlin noise.
     */

    num noise4(num x, num y, num z, num w)
    {
	num ix0, iy0, iz0, iw0, ix1, iy1, iz1, iw1;
	num fx0, fy0, fz0, fw0, fx1, fy1, fz1, fw1;
	num s, t, r, q;
	num nxyz0, nxyz1, nxy0, nxy1, nx0, nx1, n0, n1;

	ix0 = FASTFLOOR( x ); // Integer part of x
	iy0 = FASTFLOOR( y ); // Integer part of y
	iz0 = FASTFLOOR( z ); // Integer part of y
	iw0 = FASTFLOOR( w ); // Integer part of w
	fx0 = x - ix0;        // Fractional part of x
	fy0 = y - iy0;        // Fractional part of y
	fz0 = z - iz0;        // Fractional part of z
	fw0 = w - iw0;        // Fractional part of w
	fx1 = fx0 - 1.0;
	fy1 = fy0 - 1.0;
	fz1 = fz0 - 1.0;
	fw1 = fw0 - 1.0;
	ix1 = ( ix0 + 1 ) & 0xff;  // Wrap to 0..255
	iy1 = ( iy0 + 1 ) & 0xff;
	iz1 = ( iz0 + 1 ) & 0xff;
	iw1 = ( iw0 + 1 ) & 0xff;
	ix0 = ix0 & 0xff;
	iy0 = iy0 & 0xff;
	iz0 = iz0 & 0xff;
	iw0 = iw0 & 0xff;

	q = FADE( fw0 );
	r = FADE( fz0 );
	t = FADE( fy0 );
	s = FADE( fx0 );

	nxyz0 = this.grad4(this.perm[ix0 + this.perm[iy0 + this.perm[iz0 + this.perm[iw0]]]], fx0, fy0, fz0, fw0);
	nxyz1 = this.grad4(this.perm[ix0 + this.perm[iy0 + this.perm[iz0 + this.perm[iw1]]]], fx0, fy0, fz0, fw1);
	nxy0 = NLERP( q, nxyz0, nxyz1 );

	nxyz0 = this.grad4(this.perm[ix0 + this.perm[iy0 + this.perm[iz1 + this.perm[iw0]]]], fx0, fy0, fz1, fw0);
	nxyz1 = this.grad4(this.perm[ix0 + this.perm[iy0 + this.perm[iz1 + this.perm[iw1]]]], fx0, fy0, fz1, fw1);
	nxy1 = NLERP( q, nxyz0, nxyz1 );

	nx0 = NLERP ( r, nxy0, nxy1 );

	nxyz0 = this.grad4(this.perm[ix0 + this.perm[iy1 + this.perm[iz0 + this.perm[iw0]]]], fx0, fy1, fz0, fw0);
	nxyz1 = this.grad4(this.perm[ix0 + this.perm[iy1 + this.perm[iz0 + this.perm[iw1]]]], fx0, fy1, fz0, fw1);
	nxy0 = NLERP( q, nxyz0, nxyz1 );

	nxyz0 = this.grad4(this.perm[ix0 + this.perm[iy1 + this.perm[iz1 + this.perm[iw0]]]], fx0, fy1, fz1, fw0);
	nxyz1 = this.grad4(this.perm[ix0 + this.perm[iy1 + this.perm[iz1 + this.perm[iw1]]]], fx0, fy1, fz1, fw1);
	nxy1 = NLERP( q, nxyz0, nxyz1 );

	nx1 = NLERP ( r, nxy0, nxy1 );

	n0 = NLERP( t, nx0, nx1 );

	nxyz0 = this.grad4(this.perm[ix1 + this.perm[iy0 + this.perm[iz0 + this.perm[iw0]]]], fx1, fy0, fz0, fw0);
	nxyz1 = this.grad4(this.perm[ix1 + this.perm[iy0 + this.perm[iz0 + this.perm[iw1]]]], fx1, fy0, fz0, fw1);
	nxy0 = NLERP( q, nxyz0, nxyz1 );

	nxyz0 = this.grad4(this.perm[ix1 + this.perm[iy0 + this.perm[iz1 + this.perm[iw0]]]], fx1, fy0, fz1, fw0);
	nxyz1 = this.grad4(this.perm[ix1 + this.perm[iy0 + this.perm[iz1 + this.perm[iw1]]]], fx1, fy0, fz1, fw1);
	nxy1 = NLERP( q, nxyz0, nxyz1 );

	nx0 = NLERP ( r, nxy0, nxy1 );

	nxyz0 = this.grad4(this.perm[ix1 + this.perm[iy1 + this.perm[iz0 + this.perm[iw0]]]], fx1, fy1, fz0, fw0);
	nxyz1 = this.grad4(this.perm[ix1 + this.perm[iy1 + this.perm[iz0 + this.perm[iw1]]]], fx1, fy1, fz0, fw1);
	nxy0 = NLERP( q, nxyz0, nxyz1 );

	nxyz0 = this.grad4(this.perm[ix1 + this.perm[iy1 + this.perm[iz1 + this.perm[iw0]]]], fx1, fy1, fz1, fw0);
	nxyz1 = this.grad4(this.perm[ix1 + this.perm[iy1 + this.perm[iz1 + this.perm[iw1]]]], fx1, fy1, fz1, fw1);
	nxy1 = NLERP( q, nxyz0, nxyz1 );

	nx1 = NLERP ( r, nxy0, nxy1 );

	n1 = NLERP( t, nx0, nx1 );

	return 0.87 * ( NLERP( s, n0, n1 ) );
    }

    //---------------------------------------------------------------------
    /** 4D float Perlin periodic noise.
     */

    num pnoise4(num x, num y, num z, num w, num px, num py, num pz, num pw)
    {
	num ix0, iy0, iz0, iw0, ix1, iy1, iz1, iw1;
	num fx0, fy0, fz0, fw0, fx1, fy1, fz1, fw1;
	num s, t, r, q;
	num nxyz0, nxyz1, nxy0, nxy1, nx0, nx1, n0, n1;

	ix0 = FASTFLOOR( x ); // Integer part of x
	iy0 = FASTFLOOR( y ); // Integer part of y
	iz0 = FASTFLOOR( z ); // Integer part of y
	iw0 = FASTFLOOR( w ); // Integer part of w
	fx0 = x - ix0;        // Fractional part of x
	fy0 = y - iy0;        // Fractional part of y
	fz0 = z - iz0;        // Fractional part of z
	fw0 = w - iw0;        // Fractional part of w
	fx1 = fx0 - 1.0;
	fy1 = fy0 - 1.0;
	fz1 = fz0 - 1.0;
	fw1 = fw0 - 1.0;
	if (px < 1) px = 1;
	if (py < 1) py = 1;
	if (pz < 1) pz = 1;
	if (pw < 1) pw = 1;
	ix1 = (( ix0 + 1 ) % px ) & 0xff;  // Wrap to 0..px-1 and wrap to 0..255
	iy1 = (( iy0 + 1 ) % py ) & 0xff;  // Wrap to 0..py-1 and wrap to 0..255
	iz1 = (( iz0 + 1 ) % pz ) & 0xff;  // Wrap to 0..pz-1 and wrap to 0..255
	iw1 = (( iw0 + 1 ) % pw ) & 0xff;  // Wrap to 0..pw-1 and wrap to 0..255
	ix0 = ( ix0 % px ) & 0xff;
	iy0 = ( iy0 % py ) & 0xff;
	iz0 = ( iz0 % pz ) & 0xff;
	iw0 = ( iw0 % pw ) & 0xff;

	q = FADE( fw0 );
	r = FADE( fz0 );
	t = FADE( fy0 );
	s = FADE( fx0 );

	nxyz0 = this.grad4(this.perm[ix0 + this.perm[iy0 + this.perm[iz0 + this.perm[iw0]]]], fx0, fy0, fz0, fw0);
	nxyz1 = this.grad4(this.perm[ix0 + this.perm[iy0 + this.perm[iz0 + this.perm[iw1]]]], fx0, fy0, fz0, fw1);
	nxy0 = NLERP( q, nxyz0, nxyz1 );

	nxyz0 = this.grad4(this.perm[ix0 + this.perm[iy0 + this.perm[iz1 + this.perm[iw0]]]], fx0, fy0, fz1, fw0);
	nxyz1 = this.grad4(this.perm[ix0 + this.perm[iy0 + this.perm[iz1 + this.perm[iw1]]]], fx0, fy0, fz1, fw1);
	nxy1 = NLERP( q, nxyz0, nxyz1 );

	nx0 = NLERP ( r, nxy0, nxy1 );

	nxyz0 = this.grad4(this.perm[ix0 + this.perm[iy1 + this.perm[iz0 + this.perm[iw0]]]], fx0, fy1, fz0, fw0);
	nxyz1 = this.grad4(this.perm[ix0 + this.perm[iy1 + this.perm[iz0 + this.perm[iw1]]]], fx0, fy1, fz0, fw1);
	nxy0 = NLERP( q, nxyz0, nxyz1 );

	nxyz0 = this.grad4(this.perm[ix0 + this.perm[iy1 + this.perm[iz1 + this.perm[iw0]]]], fx0, fy1, fz1, fw0);
	nxyz1 = this.grad4(this.perm[ix0 + this.perm[iy1 + this.perm[iz1 + this.perm[iw1]]]], fx0, fy1, fz1, fw1);
	nxy1 = NLERP( q, nxyz0, nxyz1 );

	nx1 = NLERP ( r, nxy0, nxy1 );

	n0 = NLERP( t, nx0, nx1 );

	nxyz0 = this.grad4(this.perm[ix1 + this.perm[iy0 + this.perm[iz0 + this.perm[iw0]]]], fx1, fy0, fz0, fw0);
	nxyz1 = this.grad4(this.perm[ix1 + this.perm[iy0 + this.perm[iz0 + this.perm[iw1]]]], fx1, fy0, fz0, fw1);
	nxy0 = NLERP( q, nxyz0, nxyz1 );

	nxyz0 = this.grad4(this.perm[ix1 + this.perm[iy0 + this.perm[iz1 + this.perm[iw0]]]], fx1, fy0, fz1, fw0);
	nxyz1 = this.grad4(this.perm[ix1 + this.perm[iy0 + this.perm[iz1 + this.perm[iw1]]]], fx1, fy0, fz1, fw1);
	nxy1 = NLERP( q, nxyz0, nxyz1 );

	nx0 = NLERP ( r, nxy0, nxy1 );

	nxyz0 = this.grad4(this.perm[ix1 + this.perm[iy1 + this.perm[iz0 + this.perm[iw0]]]], fx1, fy1, fz0, fw0);
	nxyz1 = this.grad4(this.perm[ix1 + this.perm[iy1 + this.perm[iz0 + this.perm[iw1]]]], fx1, fy1, fz0, fw1);
	nxy0 = NLERP( q, nxyz0, nxyz1 );

	nxyz0 = this.grad4(this.perm[ix1 + this.perm[iy1 + this.perm[iz1 + this.perm[iw0]]]], fx1, fy1, fz1, fw0);
	nxyz1 = this.grad4(this.perm[ix1 + this.perm[iy1 + this.perm[iz1 + this.perm[iw1]]]], fx1, fy1, fz1, fw1);
	nxy1 = NLERP( q, nxyz0, nxyz1 );

	nx1 = NLERP ( r, nxy0, nxy1 );

	n1 = NLERP( t, nx0, nx1 );

	return 0.87 * ( NLERP( s, n0, n1 ) );
    }
}

