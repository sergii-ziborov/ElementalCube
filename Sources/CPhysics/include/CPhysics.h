#pragma once
#include <stdbool.h>
typedef struct ECWorld ECWorld;
typedef struct { float x, y, vx, vy, angle, mass, omega; bool grounded; } ECState;
ECWorld *ec_create(void);
void ec_destroy(ECWorld *w);
int ec_box(ECWorld *w, float x, float y, float width, float height, float density, bool dynamic, bool fixed);
void ec_remove(ECWorld *w, int id);
void ec_step(ECWorld *w, float dt);
ECState ec_state(ECWorld *w, int id);
void ec_impulse(ECWorld *w, int id, float vx, float vy);
void ec_force(ECWorld *w, int id, float fx, float fy);
void ec_force_at(ECWorld *w, int id, float fx, float fy, float x, float y);
void ec_torque(ECWorld *w, int id, float torque);
void ec_rotate(ECWorld *w, int id, float angle);
void ec_velocity(ECWorld *w, int id, float vx, float vy, float omega);
void ec_hinge(ECWorld *w, int a, int b, float x, float y);
void ec_rope(ECWorld *w, int a, int b, float ax, float ay, float bx, float by);
void ec_teleport(ECWorld *w, int id, float x, float y);
void ec_gravity(ECWorld *w, float gravity);
void ec_material(ECWorld *w, int id, float friction, float restitution);
void ec_density(ECWorld *w, int id, float density);
void ec_drive(ECWorld *w, int id, float input, float grip, bool swimming);
int ec_slope(ECWorld *w, float start, float end, bool right);
bool ec_blocked(ECWorld *w, int id, float x, float y);
bool ec_space_clear(ECWorld *w, float x, float y, float width, float height);
