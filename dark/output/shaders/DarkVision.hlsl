// phrogg eyes dark.hlsl
// 
// phroggie's version of the commonly-seen "dark mode" AV.
// 
// SPDX-License-Identifier: MIT
// Github:      https://github.com/phroggster/ns2_phrogg_eyes
// Workshop:    https://steamcommunity.com/sharedfiles/filedetails/?id=2822011098
// Workshop ID: 2822011098

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
	// TODO: remove this and make the CDT fix the sampler to use D3DTADDRESS_MIRROR instead of D3DTADDRESS_CLAMP on depthTexture.
	const float2 zero = float2(0.0000001, 0.0000001);
	const float2 one  = float2(0.9999999, 0.9999999);

	float2 pos = clamp(coord, zero, one);
	return tex2D(tex, pos);
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
	const float edgColorStrength = 0.875;
	const float entColorStrength = 0.625; // 0: vanilla plus edging; 1: excessive saturation.
	const float staticBrightness = 0.025; // 0: total black; 1: grayscale default luminance.

	const float4 colorEdging = float4(0.875, 0.875, 0.0,   1.0); // #dfdf00 / (223, 223,   0) medium yellow-green
	const float4 colorMarine = float4(0.75,  0.0,   0.625, 1.0); // #BF009F / (191,   0, 159) medium-dark magenta
	const float4 colorMarBld = float4(0.0,   0.25,  1.0,   1.0); // #0040FF / (  0,  64, 255) medium blue
	const float4 colorAliens = float4(0.6,   1.0,   0.0,   1.0); // #99FF00 / (153, 255,   0) light green
	const float4 colorGorgie = float4(0.7,   0.35,  0.0,   1.0); // #B35900 / (179,  89,   0) medium-dark orange
	const float4 colorAliBld = float4(0.0,   0.15,  0.025, 1.0); // #002606 / (  0,  38,   6) dark green
	const float4 colorOthers = float4(0.27,  0.0,   0.797, 1.0); // #4500CB / ( 69,   0, 203) medium-dark blue-(nice)-magenta

	float2 texCoord = input.texCoord;
	float4 inputPixel = tex2D(baseTexture, texCoord);

	float4 depthdata = tex2D(depthTexture, texCoord);
	float enttype = depthdata.g;
	float depthC = depthdata.r;

	// iterate neighboring pixels, and compute a normalized value indicating how edgy and cringe this one is.
	float edgeStrength =
		abs(clamp_tex2D(depthTexture, (texCoord + rcpFrame * float2(+1.0, 0.0))).r - depthC) +
		abs(clamp_tex2D(depthTexture, (texCoord + rcpFrame * float2(-1.0, 0.0))).r - depthC) +
		abs(clamp_tex2D(depthTexture, (texCoord + rcpFrame * float2(0.0, +1.0))).r - depthC) +
		abs(clamp_tex2D(depthTexture, (texCoord + rcpFrame * float2(0.0, -1.0))).r - depthC);

	if (enttype > 0.5) // entities
	{
		if (enttype > 0.99) // marines
		{
			return lerp(inputPixel, colorMarine, entColorStrength) + (edgeStrength * colorMarine);
		}
		else if (enttype > 0.97) // marine structure
		{
			return lerp(inputPixel, colorMarBld, entColorStrength) + (edgeStrength * colorMarBld);
		}
		else if (enttype > 0.95) // aliens
		{
			return lerp(inputPixel, colorAliens, amount * entColorStrength) + (edgeStrength * colorAliens);
		}
		else if (enttype > 0.93) // gorges
		{
			return lerp(inputPixel, colorGorgie, amount * entColorStrength) + (edgeStrength * colorGorgie);
		}
		else if (enttype > 0.89) // alien structures
		{
			return lerp(inputPixel, colorAliBld, amount * entColorStrength) + (edgeStrength * colorAliBld);
		}
		else // other scene entities and ready room players
		{
			return lerp(inputPixel, colorOthers, amount * entColorStrength * 0.25) + (edgeStrength * colorOthers);
		}
	}

	// world geometry, viewmodel, etc.
	float softSkybox = pow(edge * 0.9, 2.3) * step(depthC, 100);
	float softEdge = min(pow(softSkybox * 0.1, 3), 0.001);
	float darkmode = lerp(0, relative_luminance(inputPixel.rgb), amount * staticBrightness);

	if (softEdge > 0.000001)
	{
		float4 colorStaticGeom = float4(float3(darkmode + softEdge), 1.0);
		return lerp(colorStaticGeom, colorEdging, amount * edgColorStrength) + (edgeStrength * colorEdging);
	}
	else
	{
		return float4(darkmode);
	}
}
