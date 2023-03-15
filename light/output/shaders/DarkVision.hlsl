// phrogg eyes light.hlsl
// 
// phroggie's version of the commonly-seen "light mode" AV.
// 
// SPDX-License-Identifier: MIT
// Github:      https://github.com/phroggster/ns2_phrogg_eyes
// Workshop:    https://steamcommunity.com/sharedfiles/filedetails/?id=2947458601
// Workshop ID: 2947458601

#include <renderer/RenderSetup.hlsl>

struct VS_INPUT
{
	float3 ssPosition  : POSITION;
	float2 texCoord    : TEXCOORD0;
	float4 color       : COLOR0;
};

struct VS_OUTPUT
{
	float2 texCoord    : TEXCOORD0;
	float4 color       : COLOR0;
	float4 ssPosition  : SV_POSITION;
};

struct PS_INPUT
{
	float2 texCoord    : TEXCOORD0;
	float4 color       : COLOR0;
};

sampler2D baseTexture;
sampler2D depthTexture;
sampler2D normalTexture;

cbuffer LayerConstants
{
	float startTime;
	float amount;
};

/**
* Vertex shader.
*/
VS_OUTPUT SFXBasicVS(VS_INPUT input)
{
	VS_OUTPUT output;

	output.ssPosition = float4(input.ssPosition, 1);
	output.texCoord = input.texCoord + texelCenter;
	output.color = input.color;

	return output;
}

// Sample from a texture, enforcing a clamped addressing mode.
float4 clamp_tex2D(sampler2D tex, float2 coord)
{
	// TODO: remove this and make the CDT fix the sampler to use D3DTADDRESS_CLAMP instead of D3DTADDRESS_WRAP on depthTexture.
	const float2 zero = float2(0.00000000000000000000001, 0.00000000000000000000001);
	const float2 one = float2(0.99999999999999999999999, 0.99999999999999999999999);

	return tex2D(tex, clamp(coord, zero, one));
}

// Compute the relative luminance (Y) of a color value in linear space using the 2.2 power curve.
// Parameter:  RGB (float3) normalized color.
// Result:     normalized float describing how bright the pixel is. 0 = pitch black, 1 = 100% white
float relative_luminance(float3 color)
{
	// https://en.wikipedia.org/wiki/Relative_luminance
	const float Rsens = 0.2126;
	const float Gsens = 0.7152;
	const float Bsens = 0.0722;
	return clamp((color.r * Rsens) + (color.g * Gsens) + (color.b * Bsens), 0, 1);
}

float4 SFXDarkVisionPS(PS_INPUT input) : COLOR0
{
	const float entColorStrength = 0.625; // 0: vanilla plus edging; 1: excessive saturation.
	const float staticBrightness = 0.750; // 0: total black; 1: grayscale default luminance.

	const float4 colorMarine = float4(0.75,  0.0,   0.625, 1.0); // #BF009F (191,   0, 159) medium-dark magenta
	const float4 colorMarBld = float4(0.0,   0.25,  1.0,   1.0); // #0040FF (  0,  64, 255) medium blue
	const float4 colorAliens = float4(0.6,   1.0,   0.0,   1.0); // #99FF00 (153, 255,   0) light green
	const float4 colorAliBld = float4(0.0,   0.15,  0.025, 1.0); // #002606 (  0,  38,   6) dark green
	const float4 colorGorgie = float4(0.7,   0.35,  0.0,   1.0); // #B35900 (179,  89,   0) medium-dark orange
	const float4 colorOthers = float4(0.27,  0.0,   0.797, 1.0); // #4500CB ( 69,   0, 203) medium-dark blue-(nice)-magenta

	float2 texCoord = input.texCoord;
	float4 inputPixel = tex2D(baseTexture, texCoord);
	if (amount == 0)
	{
		return inputPixel;
	}

	float4 depthdata = tex2D(depthTexture, texCoord);
	// iterate neighboring pixels, and compute a scalar indicating how edgy and cringe this one is.
	float edgeStrength =
		abs(clamp_tex2D(depthTexture, (texCoord + rcpFrame * float2(+1.0,  0.0))).r - depthdata.r) +
		abs(clamp_tex2D(depthTexture, (texCoord + rcpFrame * float2(-1.0,  0.0))).r - depthdata.r) +
		abs(clamp_tex2D(depthTexture, (texCoord + rcpFrame * float2( 0.0, +1.0))).r - depthdata.r) +
		abs(clamp_tex2D(depthTexture, (texCoord + rcpFrame * float2( 0.0, -1.0))).r - depthdata.r);

	if (depthdata.g > 0.5) // entities
	{
		if (depthdata.g > 0.99) // marines
		{
			return lerp(inputPixel, colorMarine, amount * entColorStrength) + (amount * edgeStrength * colorMarine);
		}
		else if (depthdata.g > 0.97) // marine structure
		{
			return lerp(inputPixel, colorMarBld, amount * entColorStrength) + (amount * edgeStrength * colorMarBld);
		}
		else if (depthdata.g > 0.95) // aliens
		{
			return lerp(inputPixel, colorAliens, amount * entColorStrength) + (amount * edgeStrength * colorAliens);
		}
		else if (depthdata.g > 0.93) // gorges
		{
			return lerp(inputPixel, colorGorgie, amount * entColorStrength) + (amount * edgeStrength * colorGorgie);
		}
		else if (depthdata.g > 0.89) // alien structures
		{
			return lerp(inputPixel, colorAliBld, amount * entColorStrength) + (amount * edgeStrength * colorAliBld);
		}
		else // other scene entities and ready room players. Color burn effect subdued by 75%.
		{
			return lerp(inputPixel, colorOthers, amount * entColorStrength * 0.25) + (edgeStrength * colorOthers);
		}
	}
	else // world geometry, viewmodel, etc.
	{
		float outY = relative_luminance(inputPixel.rgb) * staticBrightness;
		float softenSkybox = pow(edgeStrength * 0.9, 2.3) * step(depthdata.r, 100);
		if (softenSkybox > 0.001)
		{
			// skyboxes can have some rather jarring corners; soften that up.
			float softEdge = min(pow(softenSkybox * 0.1, 3), 0);
			outY = clamp(outY + softEdge, 0.0, 1.0);
		}

		return lerp(inputPixel, float4(outY, outY, outY, 1.0), amount);
	}
}
